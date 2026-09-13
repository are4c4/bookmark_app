#!/usr/bin/env python3
"""Focused regressions for advisory Product Acceptance Evidence classification."""

from __future__ import annotations

from product_acceptance_evidence import (
    evaluate,
    parse_evidence_fields,
    probable_user_facing_ui_path,
)


def _body(
    *,
    host: str = "",
    interaction: str = "",
    visual: str = "",
    keyboard: str = "n/a",
    states: str = "n/a",
    shared: str = "n/a",
    acceptance: str = "",
) -> str:
    return f"""## Product acceptance evidence
- Real host / user scenario: {host}
- Interaction evidence: {interaction}
- Visual evidence: {visual}
- Keyboard / focus: {keyboard}
- Empty / loading / error: {states}
- Shared-host consistency: {shared}
- Acceptance criterion: {acceptance}
"""


def main() -> None:
    assert probable_user_facing_ui_path("lib/views/object_global_search_page.dart")
    assert probable_user_facing_ui_path("lib/widgets/object_relation_picker_dialog.dart")
    assert probable_user_facing_ui_path(
        "lib/features/object/presentation/widgets/object_body_document_view.dart"
    )
    assert probable_user_facing_ui_path("lib/features/foo/bar_page.dart")
    assert probable_user_facing_ui_path("lib/main.dart")
    assert not probable_user_facing_ui_path("lib/data/app_database.dart")
    assert not probable_user_facing_ui_path("lib/domain/object_model.dart")
    assert not probable_user_facing_ui_path("test/object_global_search_page_test.dart")

    parsed = parse_evidence_fields(
        _body(host="Database List / add Relation filter", acceptance="#1343 picker acceptance")
    )
    assert parsed["host"] == "Database List / add Relation filter"
    assert parsed["acceptance"] == "#1343 picker acceptance"

    non_ui = evaluate(
        ["lib/data/app_database.dart", "test/app_database_test.dart"],
        "",
        "head-non-ui",
    )
    assert not non_ui.required
    assert non_ui.status == "not-required"
    assert non_ui.missing == ()

    missing = evaluate(
        ["lib/widgets/object_relation_picker_dialog.dart"],
        _body(host="n/a", interaction="n/a", visual="none", acceptance="TBD"),
        "head-missing",
    )
    assert missing.required
    assert missing.status == "incomplete"
    assert missing.missing == (
        "Real host / user scenario",
        "Acceptance criterion",
        "Interaction evidence or Visual evidence",
    )

    visual = evaluate(
        ["lib/views/object_global_search_page.dart"],
        _body(
            host="Global Search / empty query",
            visual="UI Audit artifact + before/after screenshot",
            states="empty state confirmed",
            acceptance="#888 empty-state/readability acceptance",
        ),
        "head-visual",
    )
    assert visual.required
    assert visual.status == "complete"
    assert visual.missing == ()

    interaction = evaluate(
        ["lib/features/object/presentation/object_detail_page.dart"],
        _body(
            host="Object detail / edit Body",
            interaction="Widget test covers click → edit → save",
            keyboard="Tab focus and Enter save confirmed",
            shared="Inspector and side-peek use the same Body surface",
            acceptance="#1049 real-host Body acceptance",
        ),
        "head-interaction",
    )
    assert interaction.required
    assert interaction.status == "complete"

    # A manual "not applicable" statement cannot bypass a diff that the
    # conservative production-path classifier identifies as user-facing UI.
    attempted_bypass = evaluate(
        ["lib/ui/database_toolbar.dart"],
        _body(host="not applicable", visual="not applicable", acceptance="n/a"),
        "head-bypass",
    )
    assert attempted_bypass.required
    assert attempted_bypass.status == "incomplete"

    print("product_acceptance_evidence_test: ok")


if __name__ == "__main__":
    main()
