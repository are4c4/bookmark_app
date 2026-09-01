import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/person_roles.dart';
import '../views/bookmark_query_engine.dart';

class BookmarkListMetadata extends StatelessWidget {
  const BookmarkListMetadata({
    super.key,
    required this.bookmark,
    required this.assignments,
    required this.propertyTokens,
  });

  final BookmarkItem bookmark;
  final List<PersonRoleAssignment> assignments;
  final List<String> propertyTokens;

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    for (final token in propertyTokens) {
      if (token == 'image') continue;
      if (token.startsWith('role:')) {
        final role = token.substring(5);
        final people = assignments
            .where((assignment) => assignment.role == role)
            .map((assignment) => assignment.person)
            .toList();
        if (people.isNotEmpty) {
          widgets.add(_RoleGroup(role: role, people: people));
        }
        continue;
      }
      switch (token) {
        case 'url':
          widgets.add(_PlainMeta(text: _compactUrl(bookmark.url)));
        case 'tags':
          widgets.addAll(
            bookmark.tags.map(
              (tag) => _MetaChip(
                icon: Icons.sell_outlined,
                label: tag.name,
              ),
            ),
          );
        case 'people':
          widgets.addAll(
            bookmark.people.map(
              (person) => _MetaChip(
                icon: Icons.person_outline,
                label: person.name,
              ),
            ),
          );
        case 'description':
          if (bookmark.description?.trim().isNotEmpty == true) {
            widgets.add(_PlainMeta(text: bookmark.description!));
          }
        case 'createdAt':
          widgets.add(_PlainMeta(text: _formatDate(bookmark.createdAt)));
        case 'favorite':
          if (bookmark.favorite) {
            widgets.add(
              const _MetaChip(icon: Icons.star, label: 'お気に入り'),
            );
          }
        case 'status':
          widgets.add(
            _MetaChip(
              icon: Icons.flag_outlined,
              label: bookmarkStatusLabels[bookmark.status] ?? bookmark.status,
            ),
          );
        case 'rating':
          if (bookmark.rating > 0) {
            widgets.add(_PlainMeta(text: '★' * bookmark.rating));
          }
        case 'history':
          widgets.add(
            _PlainMeta(
              text: bookmark.lastOpenedAt == null
                  ? '${bookmark.openCount}回 · 未閲覧'
                  : '${bookmark.openCount}回 · ${_formatDate(bookmark.lastOpenedAt!)}',
            ),
          );
      }
    }
    if (widgets.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: widgets,
    );
  }

  static String _compactUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return value;
    return uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          if (role.isNotEmpty && role != '出演者') ...[
            Text(
              '$role ',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              people.length <= 3
                  ? people.map((person) => person.name).join('、')
                  : '${people.first.name} ほか${people.length - 1}人',
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
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
          Text(label, style: const TextStyle(fontSize: 11.5)),
        ],
      ),
    );
  }
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
