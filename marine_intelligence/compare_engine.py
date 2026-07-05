from __future__ import annotations

from typing import List, Literal, Optional, Tuple

from marine_intelligence.models import (
    MarineComparisonModel,
    MarineCoordinateResponseModel,
)

CompareWinner = Literal["left", "right", "tie"]

_GO_SCORE_TIE_THRESHOLD = 5
_HIGH_RISK_THRESHOLD = 65
_RISK_PENALTY_START = 55


def _go_score(report: MarineCoordinateResponseModel) -> int:
    if report.decision and report.decision.go_score is not None:
        return int(report.decision.go_score)
    return int(report.fishing_score.suitability_score)


def _risk_score(report: MarineCoordinateResponseModel) -> int:
    return int(report.fishing_score.risk_score)


def _confidence_pct(report: MarineCoordinateResponseModel) -> int:
    conf = report.consensus_summary.overall_confidence
    if conf > 0:
        return int(round(conf * 100))
    return int(round(report.fishing_score.confidence * 100))


def _effective_score(go_score: int, risk_score: int) -> int:
    penalty = 0
    if risk_score >= _HIGH_RISK_THRESHOLD:
        penalty = (risk_score - _RISK_PENALTY_START) // 2
    return go_score - penalty


def _best_timeline_label(report: MarineCoordinateResponseModel) -> Optional[str]:
    timeline = report.decision_timeline or []
    if not timeline:
        return None
    best = next((item for item in timeline if item.is_best_slot), None)
    if best is None:
        best = max(timeline, key=lambda item: item.go_score or 0)
    if best.go_score is None:
        return best.time
    return f"{best.time} (git {best.go_score})"


def _sensitive_factor(report: MarineCoordinateResponseModel) -> Optional[str]:
    if report.explainability and report.explainability.most_sensitive_factor_tr:
        return report.explainability.most_sensitive_factor_tr
    if report.scenario and report.scenario.items:
        ranked = sorted(
            report.scenario.items,
            key=lambda item: abs(item.delta_go_score or 0) + abs(item.delta_risk_score or 0),
            reverse=True,
        )
        return ranked[0].title_tr
    return None


def compute_comparison(
    left_report: MarineCoordinateResponseModel,
    right_report: MarineCoordinateResponseModel,
    *,
    left_label: str,
    right_label: str,
) -> MarineComparisonModel:
    left_go = _go_score(left_report)
    right_go = _go_score(right_report)
    left_risk = _risk_score(left_report)
    right_risk = _risk_score(right_report)
    left_conf = _confidence_pct(left_report)
    right_conf = _confidence_pct(right_report)

    score_delta = left_go - right_go
    risk_delta = left_risk - right_risk
    confidence_delta = left_conf - right_conf

    left_effective = _effective_score(left_go, left_risk)
    right_effective = _effective_score(right_go, right_risk)
    effective_delta = left_effective - right_effective

    winner: CompareWinner
    if abs(score_delta) < _GO_SCORE_TIE_THRESHOLD or abs(effective_delta) < _GO_SCORE_TIE_THRESHOLD:
        winner = "tie"
    elif left_effective > right_effective:
        winner = "left"
    else:
        winner = "right"

    if winner != "tie" and abs(effective_delta) < _GO_SCORE_TIE_THRESHOLD + 2:
        winner = "tie"

    winner_label: Optional[str] = None
    if winner == "left":
        winner_label = left_label
    elif winner == "right":
        winner_label = right_label

    main_reasons = _build_main_reasons(
        left_report,
        right_report,
        left_label=left_label,
        right_label=right_label,
        left_go=left_go,
        right_go=right_go,
        left_risk=left_risk,
        right_risk=right_risk,
        left_conf=left_conf,
        right_conf=right_conf,
    )

    decision_delta_tr = _decision_delta_tr(
        winner=winner,
        left_label=left_label,
        right_label=right_label,
        score_delta=score_delta,
        risk_delta=risk_delta,
    )
    risk_note_tr = _risk_note_tr(left_risk, right_risk, left_label, right_label)
    summary_tr = _summary_tr(
        winner=winner,
        left_label=left_label,
        right_label=right_label,
        score_delta=score_delta,
        left_conf=left_conf,
        right_conf=right_conf,
        main_reasons=main_reasons,
    )

    return MarineComparisonModel(
        winner=winner,
        winner_label=winner_label,
        score_delta=score_delta,
        risk_delta=risk_delta,
        confidence_delta=confidence_delta,
        decision_delta_tr=decision_delta_tr,
        main_reasons=main_reasons,
        risk_note_tr=risk_note_tr,
        summary_tr=summary_tr,
    )


def _build_main_reasons(
    left_report: MarineCoordinateResponseModel,
    right_report: MarineCoordinateResponseModel,
    *,
    left_label: str,
    right_label: str,
    left_go: int,
    right_go: int,
    left_risk: int,
    right_risk: int,
    left_conf: int,
    right_conf: int,
) -> List[str]:
    reasons: List[str] = []

    if left_go != right_go:
        better = left_label if left_go > right_go else right_label
        reasons.append(
            f"{better} git skoru daha yüksek ({max(left_go, right_go)} vs {min(left_go, right_go)})."
        )

    if abs(left_risk - right_risk) >= 8:
        lower = left_label if left_risk < right_risk else right_label
        reasons.append(
            f"{lower} risk skoru daha düşük ({min(left_risk, right_risk)} vs {max(left_risk, right_risk)})."
        )

    if abs(left_conf - right_conf) >= 10:
        higher = left_label if left_conf > right_conf else right_label
        reasons.append(
            f"{higher} veri güveni daha yüksek (%{max(left_conf, right_conf)} vs %{min(left_conf, right_conf)})."
        )

    left_sensitive = _sensitive_factor(left_report)
    right_sensitive = _sensitive_factor(right_report)
    if left_sensitive and left_sensitive != right_sensitive:
        reasons.append(f"{left_label} hassas faktör: {left_sensitive}.")
    if right_sensitive and right_sensitive != left_sensitive:
        reasons.append(f"{right_label} hassas faktör: {right_sensitive}.")

    left_best = _best_timeline_label(left_report)
    right_best = _best_timeline_label(right_report)
    if left_best and right_best and left_best != right_best:
        reasons.append(f"En iyi pencere: {left_label} {left_best}, {right_label} {right_best}.")

    if left_report.partial_data:
        reasons.append(f"{left_label} için kısmi veri — belirsizlik yüksek olabilir.")
    if right_report.partial_data:
        reasons.append(f"{right_label} için kısmi veri — belirsizlik yüksek olabilir.")

    if left_report.consensus_summary.partial_providers:
        reasons.append(f"{left_label} sağlayıcı verisi kısmi.")
    if right_report.consensus_summary.partial_providers:
        reasons.append(f"{right_label} sağlayıcı verisi kısmi.")

    return reasons[:6]


def _decision_delta_tr(
    *,
    winner: CompareWinner,
    left_label: str,
    right_label: str,
    score_delta: int,
    risk_delta: int,
) -> str:
    if winner == "tie":
        return (
            f"{left_label} ile {right_label} git skorları birbirine yakın "
            f"(fark {score_delta:+d}). Karar belirsiz; yerel koşulları doğrulayın."
        )
    winner_label = left_label if winner == "left" else right_label
    loser_label = right_label if winner == "left" else left_label
    parts = [
        f"{winner_label}, {loser_label}'e göre git skoru açısından biraz daha avantajlı görünüyor "
        f"(fark {abs(score_delta)} puan, olasılıksal)."
    ]
    if risk_delta != 0:
        lower = left_label if risk_delta < 0 else right_label
        parts.append(f"Risk açısından {lower} biraz daha düşük.")
    return " ".join(parts)


def _risk_note_tr(
    left_risk: int,
    right_risk: int,
    left_label: str,
    right_label: str,
) -> Optional[str]:
    max_risk = max(left_risk, right_risk)
    if max_risk < 50:
        return None
    high_side = left_label if left_risk >= right_risk else right_label
    return (
        f"{high_side} risk skoru {max_risk}/100 — resmi deniz ve hava uyarılarını "
        "mutlaka kontrol edin."
    )


def _summary_tr(
    *,
    winner: CompareWinner,
    left_label: str,
    right_label: str,
    score_delta: int,
    left_conf: int,
    right_conf: int,
    main_reasons: List[str],
) -> str:
    min_conf = min(left_conf, right_conf)
    caution = ""
    if min_conf < 50:
        caution = " Veri güveni sınırlı; temkinli değerlendirin."

    if winner == "tie":
        return (
            f"{left_label} ve {right_label} benzer seviyede görünüyor. "
            f"Git skoru farkı {abs(score_delta)} puan.{caution}"
        )

    winner_label = left_label if winner == "left" else right_label
    loser_label = right_label if winner == "left" else left_label
    headline = (
        f"{winner_label}, {loser_label}'e kıyasla genel olarak biraz daha uygun görünüyor "
        f"(git skoru farkı {abs(score_delta)})."
    )
    if main_reasons:
        headline += f" {main_reasons[0]}"
    return headline + caution
