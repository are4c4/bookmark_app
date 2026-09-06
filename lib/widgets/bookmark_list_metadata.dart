import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/person_roles.dart';
import '../services/bookmark_url_resolver.dart';
import '../views/bookmark_query_engine.dart';
import 'bookmark_resolved_url_text.dart';

class BookmarkListMetadata extends StatelessWidget {
  const BookmarkListMetadata({
    super.key,
    required this.bookmark,
    required this.assignments,
    required this.propertyTokens,
    this.resolveUrl,
  });

  final BookmarkItem bookmark;
  final List<PersonRoleAssignment> assignments;
  final List<String> propertyTokens;
  final BookmarkUrlResolve? resolveUrl;

  @override
  Widget build(BuildContext context) {
    Widget? description;
    final secondary = <Widget>[];
    final chips = <Widget>[];
    for (final token in propertyTokens) {
      if (token == 'image') continue;
      if (token.startsWith('role:')) {
        final role = token.substring(5);
        final people = assignments
            .where((assignment) => assignment.role == role)
            .map((assignment) => assignment.person)
            .toList();
        if (people.isNotEmpty) {
          chips.add(_RoleGroup(role: role, people: people));
        }
        continue;
      }
      switch (token) {
        case 'url':
          final resolver = resolveUrl;
          if (resolver != null) {
            secondary.add(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: BookmarkResolvedUrlText(
                  bookmark: bookmark,
                  resolveUrl: resolver,
                  compact: true,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
        case 'tags':
          chips.addAll(
            bookmark.tags.map(
              (tag) => _MetaChip(
                icon: Icons.sell_outlined,
                label: tag.name,
              ),
            ),
          );
        case 'people':
          chips.addAll(
            bookmark.people.map(
              (person) => _MetaChip(
                icon: Icons.person_outline,
                label: person.name,
              ),
            ),
          );
        case 'description':
          if (bookmark.description?.trim().isNotEmpty == true) {
            description = _DescriptionMeta(text: bookmark.description!);
          }
        case 'createdAt':
          secondary.add(_PlainMeta(text: _formatDate(bookmark.createdAt)));
        case 'favorite':
          if (bookmark.favorite) {
            chips.add(
              const _MetaChip(icon: Icons.star, label: 'お気に入り'),
            );
          }
        case 'status':
          chips.add(
            _MetaChip(
              icon: Icons.flag_outlined,
              label: bookmarkStatusLabels[bookmark.status] ?? bookmark.status,
            ),
          );
        case 'rating':
          if (bookmark.rating > 0) {
            secondary.add(_PlainMeta(text: '★' * bookmark.rating));
          }
        case 'history':
          secondary.add(
            _PlainMeta(
              text: bookmark.lastOpenedAt == null
                  ? '${bookmark.openCount}回 · 未閲覧'
                  : '${bookmark.openCount}回 · ${_formatDate(bookmark.lastOpenedAt!)}',
            ),
          );
      }
    }
    if (description == null && secondary.isEmpty && chips.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (description != null)
          KeyedSubtree(
            key: const ValueKey('bookmark-list-description-metadata'),
            child: description,
          ),
        if (description != null && secondary.isNotEmpty)
          const SizedBox(height: 5),
        if (secondary.isNotEmpty)
          Wrap(
            key: const ValueKey('bookmark-list-secondary-metadata'),
            spacing: 9,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: secondary,
          ),
        if ((description != null || secondary.isNotEmpty) && chips.isNotEmpty)
          const SizedBox(height: 8),
        if (chips.isNotEmpty)
          Wrap(
            key: const ValueKey('bookmark-list-chip-metadata'),
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: chips,
          ),
      ],
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  }
}

class _RoleGroup extends StatelessWidget {
  const _RoleGroup({required this.role, required this.people});

  final String role;
  final List<Person> people;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (role.isNotEmpty && role != '出演者')
          Text(
            '$role:',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ...people.map(
          (person) => _MetaChip(
            icon: Icons.person_outline,
            label: person.name,
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionMeta extends StatelessWidget {
  const _DescriptionMeta({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          height: 1.25,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
}

class _PlainMeta extends StatelessWidget {
  const _PlainMeta({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}
