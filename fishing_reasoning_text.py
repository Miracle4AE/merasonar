"""
Batimetrik göstergelerden türetilen yalın açıklamalar (harici LLM yok).

``hotspot.reasoning_text`` (en fazla ~2 cümle) ve ``hotspot.fish_prediction`` üretir.
Genel davranış heuristikleri; bölge ve GPS’ten bağımsız Türkçe metinler.
"""

from __future__ import annotations

import hashlib
from typing import Any, Dict, List, Mapping


def _f(v: Any, default: float = 0.0) -> float:
    try:
        x = float(v)
    except (TypeError, ValueError):
        return default
    if x != x:
        return default
    return x


def _depth_profile(metrics: Mapping[str, Any]) -> str:
    """Metriklerden kaba dip rejimi (GPS yok)."""
    flat_p = _f(metrics.get("flat_penalty"))
    basin = _f(metrics.get("basin_likelihood"))
    slope = _f(metrics.get("slope"))
    drop = _f(metrics.get("dropoff_proximity"))
    trans = _f(metrics.get("transition_band"))
    cd = _f(metrics.get("contour_density"))
    gradient = (slope + drop + trans) / 3.0
    pocket = _f(metrics.get("pocket"))

    if flat_p >= 0.42 and gradient < 0.42:
        return "gentle"
    if basin >= 0.52 or pocket >= 0.48:
        return "basin"
    if gradient >= 0.52 or drop >= 0.58:
        return "steep"
    if cd >= 0.55 and gradient < 0.5:
        return "contour_shallow"
    if gradient <= 0.38:
        return "shallow_mixed"
    return "moderate"


def _candidate_species_order(
    metrics: Mapping[str, Any],
    depth_prof: str,
    struct_prox: float,
    contour_d: float,
    transition_band: float,
    nearby_peer_count: int,
    salt: int,
) -> List[str]:
    ridge = _f(metrics.get("ridge_likelihood"))
    saddle = _f(metrics.get("saddle"))
    ordered: List[str] = []

    def push(*names: str) -> None:
        for n in names:
            if n not in ordered:
                ordered.append(n)

    if depth_prof == "steep":
        push("orfoz", "amberjack", "siniper")
    elif depth_prof == "gentle":
        push("çipura", "dil balığı", "levrek")
    elif depth_prof == "basin":
        push("dil balığı", "levrek", "siniper")
    elif depth_prof == "contour_shallow":
        push("levrek", "çipura", "siniper")
    elif depth_prof == "shallow_mixed":
        push("siniper", "çipura", "uskumru")
    else:
        push("levrek", "siniper", "lufer")

    if struct_prox >= 0.42:
        push("orfoz")
    if contour_d >= 0.52:
        push("levrek")
    if ridge >= 0.48 or saddle >= 0.45:
        push("siniper")
    if transition_band >= 0.52:
        push("palamut", "amberjack")
    if nearby_peer_count >= 2:
        push("sarıkanat", "uskumru")
    elif nearby_peer_count == 1:
        push("gezinen sıprılar")

    n = len(ordered)
    if n <= 3:
        return ordered
    h = int(hashlib.sha256(f"sp|{salt}".encode()).hexdigest()[:12], 16)
    ix = list(range(n))
    ix.sort(key=lambda i: (h >> (i * 5 % 24)) % 1000)
    reranked = [ordered[i] for i in ix]
    return reranked


def build_fish_prediction(
    metrics: Mapping[str, Any],
    classification: str,
    hotspot_id: int,
    rank: int,
    nearby_peer_count: int,
) -> str:
    cls = (classification or "C").strip().upper()[:1]
    if cls not in ("A", "B", "C"):
        cls = "C"

    cd = _f(metrics.get("contour_density"))
    struct_prox = max(
        _f(metrics.get("structure_score")),
        _f(metrics.get("structure_intersection")),
        _f(metrics.get("breakline_edge")),
        _f(metrics.get("ridge_likelihood")),
        _f(metrics.get("basin_likelihood")),
    )
    tb = _f(metrics.get("transition_band"))
    depth_prof = _depth_profile(metrics)
    salt = int(hotspot_id) * 10007 + int(rank) * 131

    ranked = _candidate_species_order(
        metrics, depth_prof, struct_prox, cd, tb, nearby_peer_count, salt
    )

    uniq: List[str] = []
    for s in ranked:
        if s not in uniq:
            uniq.append(s)
        if len(uniq) >= 3:
            break
    if not uniq:
        uniq = ["kıyı avcıları", "siniper grubu"]

    three = uniq[:3]
    species_line = ", ".join(three)

    if cls == "A":
        prefix = _pick(
            [
                "Olası hedef türler",
                "Güçlü adaylar",
                "Öne çıkan türler",
            ],
            "fpA",
            salt,
            rank,
        )
        return f"{prefix}: {species_line}"
    if cls == "B":
        prefix = _pick(
            [
                "Makul tür seçenekleri",
                "Denebilir adaylar",
                "Uygun görülen balıklar",
            ],
            "fpB",
            salt,
            rank,
        )
        return f"{prefix}: {species_line}"
    return _pick(
        [
            f"Tür bağlamında {species_line} düşünülebilir.",
            f"{species_line} arasında olasılık içerir; belirsiz kabul edin.",
            f"{species_line} için umut sınırlı; yerel bilgi şarttır.",
        ],
        "fpC",
        salt ^ 401,
        rank,
    )


def _pick(variants: List[str], key: str, salt: int, rank: int) -> str:
    if not variants:
        return ""
    raw = hashlib.sha256(f"{key}|{salt}|{rank}|v2".encode("utf-8")).hexdigest()
    return variants[int(raw[:12], 16) % len(variants)]


def build_hotspot_reasoning_text(
    *,
    metrics: Mapping[str, Any],
    classification: str,
    hotspot_id: int,
    rank: int,
    nearby_peer_count: int,
) -> str:
    cls = (classification or "C").strip().upper()[:1]
    if cls not in ("A", "B", "C"):
        cls = "C"

    cd = _f(metrics.get("contour_density"))
    slope = _f(metrics.get("slope"))
    drop = _f(metrics.get("dropoff_proximity"))
    trans = _f(metrics.get("transition_band"))
    depth_grad = (slope + drop + trans) / 3.0

    struct_prox = max(
        _f(metrics.get("structure_score")),
        _f(metrics.get("structure_intersection")),
        _f(metrics.get("breakline_edge")),
        _f(metrics.get("ridge_likelihood")),
        _f(metrics.get("basin_likelihood")),
    )

    drivers: List[tuple[str, float]] = [
        ("contour", cd),
        ("depth", depth_grad),
        ("structure", struct_prox),
    ]
    drivers.sort(key=lambda t: -t[1])
    primary = drivers[0][0]
    secondary = drivers[1][0] if len(drivers) > 1 else primary

    salt = int(hotspot_id) * 10007 + int(rank) * 131

    if nearby_peer_count >= 2:
        seg_cluster = _pick(
            [
                "Birkaç umut verici işaret kümelenmiş; balığın aynı geçit hattında toplanması sık görülür.",
                "Sıkı bir mera grubu içindeyiz; beslenme hareketinin yoğunlaşması olasıdır.",
                "Komşu işaretler çok yakın; gelgit döngüsünde avcıların bu nöbetler arasında döndüğü olur.",
            ],
            "cl",
            salt,
            rank,
        )
    elif nearby_peer_count == 1:
        seg_cluster = _pick(
            [
                "Yanında yakın başka işaret var; biri kesilirse ikinciye kaymak mümkün olabilir.",
                "İkinci bir nokta eşlik ediyor; küçük bir mahallede yavaş sürmek doğru olabilir.",
            ],
            "cp",
            salt,
            rank,
        )
    else:
        seg_cluster = ""

    if primary == "contour" and cd >= 0.48:
        seg_main = _pick(
            [
                "Sıkı kontur çizgileri keskin bir derinlik geçişine işaret eder; pusuya dayalı ovada sık görülür.",
                "Konturlar güçlü bir relef kopuşunu düşündürür; akıntı böler, yemi biriktirip avcıları toplar.",
                "Kalabalık konturlar dipsel dokuyu karmaşık yapar; gezinerek avcılar burayı sıkça tarar.",
                "Çizgiler sıkıştığı yüzölçümde yem yamaç üzerinde sıkıştırılar; tepeden balığa yaklaşma tipik olabilir.",
            ],
            "c1",
            salt ^ 3,
            rank,
        )
    elif primary == "depth" and depth_grad >= 0.45:
        seg_main = _pick(
            [
                "Somut bir derinlik geçişi balığa avlanırken sarılabileceği cephe verir.",
                "Taban bir mikro basamaktan çıkar; yem kümelenmesi ve avcı izi klasik olarak üst üste biner.",
                "Belirgin eğim; hareket eden balıklar için yumuşak bir otoyol işlevi görür.",
                "Derinlik adımında hem dip hem ara su avcısı aynı kırığı paylaşıp durabilir.",
            ],
            "d1",
            salt ^ 5,
            rank,
        )
    elif primary == "structure" and struct_prox >= 0.45:
        seg_main = _pick(
            [
                "Dip yapısı öne çıkar; süzülürken sığınma ve pusuya uygun yüzler sağlar.",
                "Kabartı ve yapı bileşimi gelgit hareketinde oyun balığının ilgisini çeker.",
                "Yeterince belirgin bir yapıdır; sıradan süzülüşü net bir atağa döndürülebilir.",
                "Sert veya sığınak kabartı klasik olarak çıkandan baskın avcıların alanıdır.",
            ],
            "s1",
            salt ^ 7,
            rank,
        )
    else:
        seg_main = _pick(
            [
                "Hikaye zayıftır ama yine ilgi çekebilecek yeterince kabartı ve doku içerir.",
                "Karışık sinyaller olsa bile derinlik ve doku uyumu ara sıra seçici vuruş çıkarır.",
                "Çizilen taban uç görünümde sıradandır ama doğru koşulda patlayabilir.",
                "Hafif kabartılı alan bile hafif akıntıda süzülmeyle dip süzülmesini konsantre eder.",
            ],
            "m1",
            salt ^ 11,
            rank,
        )

    extra = ""
    if secondary != primary:
        if secondary == "structure" and struct_prox >= 0.38:
            extra = _pick(
                [
                    " Yakın yapının gölgesi ipuçlarını güçlendirebilir.",
                    " Çıkının etkisi dikkatli sunum için arkaplanda sürebilir.",
                ],
                "s2",
                salt ^ 13,
                rank,
            )
        elif secondary == "contour" and cd >= 0.38:
            extra = _pick(
                [
                    " Ek kontur detayı atışı daha hassas yere düşürmenize yarar.",
                    " Konturdaki mikro kopuş yavaş al-çek sırasında fark çıkarır.",
                ],
                "c2",
                salt ^ 17,
                rank,
            )

    sentence1 = (seg_cluster + " " if seg_cluster else "") + seg_main + extra
    sentence1 = " ".join(sentence1.split())
    if len(sentence1) > 280:
        sentence1 = sentence1[:277].rstrip() + "..."

    if cls == "A":
        sentence2 = _pick(
            [
                "Genelde güçlü bir durak olarak düşünülebilir; koşullar oturunca somut şans daha yüksektir.",
                "Öncelikli rota olarak değerlendirin; sıra oluşunca sağlam ısırığa yaklaşmış olabilirsiniz.",
                "Ciddi tutunma yerine yaklaşabileceği bir sahne olarak düşünün; rüzgâr ve gelgit uyunca verim artar.",
            ],
            "A",
            salt ^ 101,
            rank,
        )
    elif cls == "B":
        sentence2 = _pick(
            [
                "Makul bir şans olarak sabırlı denemeye değer; ilk süzülüş sessizse hız ya da kotu güncelleyin.",
                "Beklentileri düşük tutun ama ayrılırken zaman tanıyın.",
                "B planında sağlam aday olarak gözününüzde bulundurun; ışık veya akıntı döndükçe açılabilir.",
            ],
            "B",
            salt ^ 202,
            rank,
        )
    else:
        sentence2 = _pick(
            [
                "Güven daha düşük; hızlı bir keşif durağı gibi kullanın.",
                "Denemenin eğlenceli olduğu ama rekor gün garantisi taşımadığı yaklaşım.",
                "Güçlü işaretler arasında gezinirken doldurmak için elverişli.",
            ],
            "C",
            salt ^ 303,
            rank,
        )

    return f"{sentence1} {sentence2}".strip()


def apply_reasoning_text_to_hotspots(
    hotspots: List[Dict[str, Any]],
    image_width: int,
    image_height: int,
) -> None:
    """``reasoning_text`` üretir (piksel yakınlığına göre)."""
    if not hotspots:
        return
    w = max(1, int(image_width))
    h = max(1, int(image_height))
    thresh = max(12.0, min(w, h) * 0.018)
    thresh2 = thresh * thresh

    coords: List[tuple[float, float]] = []
    for hp in hotspots:
        pc = hp.get("pixel_centroid")
        if isinstance(pc, Mapping):
            cx = _f(pc.get("x"))
            cy = _f(pc.get("y"))
        else:
            cx = _f(hp.get("x"))
            cy = _f(hp.get("y"))
        coords.append((cx, cy))

    for i, hp in enumerate(hotspots):
        peers = 0
        x0, y0 = coords[i]
        for j, (x1, y1) in enumerate(coords):
            if i == j:
                continue
            dx = x0 - x1
            dy = y0 - y1
            if dx * dx + dy * dy <= thresh2:
                peers += 1
        hid = int(hp.get("id", i))
        rk = int(hp.get("rank", hp.get("rank_overall", i + 1)))
        m = hp.get("supporting_metrics")
        m_map = m if isinstance(m, Mapping) else {}
        hp["reasoning_text"] = build_hotspot_reasoning_text(
            metrics=m_map,
            classification=str(hp.get("classification", "C")),
            hotspot_id=hid,
            rank=rk,
            nearby_peer_count=peers,
        )
        hp["fish_prediction"] = build_fish_prediction(
            m_map,
            str(hp.get("classification", "C")),
            hid,
            rk,
            peers,
        )
