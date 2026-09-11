import 'object_merge_contract.dart';
import 'object_merge_state_planner.dart';

/// Exact frozen Object state and preview used to build one explicit merge plan.
///
/// Keeping the snapshots and preview together prevents a plan prepared for an
/// older same-id Object state from being paired with later snapshots that happen
/// to expose the same conflict shape.
class ObjectMergePreparedState {
  ObjectMergePreparedState._({
    required this.survivor,
    required this.retired,
    required this.preview,
  });

  factory ObjectMergePreparedState.prepare({
    required ObjectMergeStateSnapshot survivor,
    required ObjectMergeStateSnapshot retired,
    List<ObjectMergeRelationBlocker> relationBlockers =
        const <ObjectMergeRelationBlocker>[],
  }) {
    const planner = ObjectMergeStatePlanner();
    final preview = planner.preview(
      survivor: survivor,
      retired: retired,
      relationBlockers: relationBlockers,
    );
    return ObjectMergePreparedState._(
      survivor: survivor,
      retired: retired,
      preview: preview,
    );
  }

  final ObjectMergeStateSnapshot survivor;
  final ObjectMergeStateSnapshot retired;
  final ObjectMergePreview preview;

  ObjectMergePlan plan({
    Map<String, ObjectMergeDecision> decisions =
        const <String, ObjectMergeDecision>{},
  }) => preview.plan(decisions: decisions);
}

/// Pure resolver for A-owned Object merge state after every explicit decision
/// has been made.
///
/// The returned snapshot is still only proposed state. Persistence, Relation
/// rewiring, retired Object deletion and redirect writes belong to later
/// coordinating layers.
class ObjectMergeStateMaterializer {
  const ObjectMergeStateMaterializer();

  ObjectMergeStateSnapshot materialize({
    required ObjectMergePreparedState prepared,
    required ObjectMergePlan plan,
  }) {
    if (!identical(plan.preview, prepared.preview)) {
      throw StateError(
        'Object merge plan was not built from this prepared Object state.',
      );
    }
    if (!plan.isExecutable) {
      throw StateError(
        'Object merge state cannot be materialized until every decision and Relation blocker is resolved.',
      );
    }

    final requirements = <String, ObjectMergeRequirement>{
      for (final requirement in prepared.preview.requirements)
        requirement.key: requirement,
    };

    final title = _selectValue<String>(
      key: 'title',
      requirements: requirements,
      plan: plan,
      survivorValue: prepared.survivor.title,
      retiredValue: prepared.retired.title,
    );

    final retiredProperties = <int, ObjectMergeValuePropertySnapshot>{
      for (final property in prepared.retired.propertySnapshots)
        property.propertyId: property,
    };
    final properties = <ObjectMergeValuePropertySnapshot>[];
    for (final survivorProperty in prepared.survivor.propertySnapshots) {
      final retiredProperty = retiredProperties[survivorProperty.propertyId];
      if (retiredProperty == null ||
          retiredProperty.type != survivorProperty.type) {
        throw StateError(
          'Prepared Object merge Property identity/type state is inconsistent.',
        );
      }
      properties.add(
        _selectValue<ObjectMergeValuePropertySnapshot>(
          key: 'property:${survivorProperty.propertyId}',
          requirements: requirements,
          plan: plan,
          survivorValue: survivorProperty,
          retiredValue: retiredProperty,
        ),
      );
    }

    final body = _selectValue(
      key: 'body',
      requirements: requirements,
      plan: plan,
      survivorValue: prepared.survivor.body,
      retiredValue: prepared.retired.body,
    );

    final aliasesRequirement = requirements['aliases'];
    if (aliasesRequirement == null ||
        aliasesRequirement.kind != ObjectMergeStateKind.aliases) {
      throw StateError('Prepared Object merge aliases requirement is missing.');
    }
    final aliasesDecision = _decisionFor(
      requirement: aliasesRequirement,
      plan: plan,
    );
    final aliases = switch (aliasesDecision) {
      null || ObjectMergeDecision.keepSurvivor => prepared.survivor.aliases,
      ObjectMergeDecision.takeRetired => prepared.retired.aliases,
      ObjectMergeDecision.combine =>
        const ObjectMergeStatePlanner().combineAliases(
          survivor: prepared.survivor,
          retired: prepared.retired,
        ),
    };

    final lifecycleRequirement = requirements['lifecycle'];
    if (lifecycleRequirement == null ||
        lifecycleRequirement.kind != ObjectMergeStateKind.lifecycle ||
        lifecycleRequirement.requiresDecision) {
      throw StateError(
        'Prepared Object merge lifecycle policy must remain survivor-compatible.',
      );
    }

    return ObjectMergeStateSnapshot(
      objectId: prepared.survivor.objectId,
      objectTypeId: prepared.survivor.objectTypeId,
      title: title,
      propertySnapshots: properties,
      body: body,
      aliases: aliases,
    );
  }

  T _selectValue<T>({
    required String key,
    required Map<String, ObjectMergeRequirement> requirements,
    required ObjectMergePlan plan,
    required T survivorValue,
    required T retiredValue,
  }) {
    final requirement = requirements[key];
    if (requirement == null) {
      throw StateError('Prepared Object merge requirement $key is missing.');
    }
    final decision = _decisionFor(requirement: requirement, plan: plan);
    return switch (decision) {
      null || ObjectMergeDecision.keepSurvivor => survivorValue,
      ObjectMergeDecision.takeRetired => retiredValue,
      ObjectMergeDecision.combine => throw StateError(
        'Object merge requirement $key cannot be combined.',
      ),
    };
  }

  ObjectMergeDecision? _decisionFor({
    required ObjectMergeRequirement requirement,
    required ObjectMergePlan plan,
  }) {
    if (!requirement.requiresDecision) return null;
    final decision = plan.decisions[requirement.key];
    if (decision == null) {
      throw StateError(
        'Executable Object merge plan is missing ${requirement.key}.',
      );
    }
    return decision;
  }
}
