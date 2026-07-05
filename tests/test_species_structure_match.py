import unittest

from species_structure_match import compute_species_matches, map_scientific_to_group


class SpeciesStructureMatchTests(unittest.TestCase):
    def test_map_genus_dicentrarchus(self) -> None:
        m = map_scientific_to_group("Dicentrarchus labrax")
        self.assertIsNotNone(m)
        assert m is not None
        self.assertEqual(m[1], "ambush_predator")

    def test_compute_matches_links_structure_and_regional_list(self) -> None:
        hotspot = {
            "feature_type": "drop_off",
            "supporting_metrics": {
                "slope": 0.82,
                "contour_density": 0.7,
                "dropoff_proximity": 0.74,
                "structure_score": 0.5,
                "ridge_likelihood": 0.2,
                "basin_likelihood": 0.1,
                "transition_band": 0.3,
                "local_relief": 0.4,
                "coast_distance_px": 20.0,
            },
        }
        regional = [
            "Dicentrarchus labrax",
            "Epinephelus marginatus",
            "SomeUnknownus foobar",
        ]
        out = compute_species_matches(hotspot, regional, max_items=3)
        self.assertLessEqual(len(out), 3)
        self.assertGreaterEqual(len(out), 1)
        for row in out:
            self.assertIn("species", row)
            self.assertIn("confidence", row)
            self.assertIn("reason", row)
            self.assertRegex(row["confidence"].lower(), r"^(yüksek|orta|düşük)$")
            # Prose cites regional list + structural nuance (Turkish output)
            rl = row["reason"].lower()
            self.assertTrue(
                ("bölgesel" in rl or "bulun" in rl or "kayıtların" in rl)
                and (
                    "yapı" in rl
                    or "metrik" in rl
                    or "dip" in rl
                    or "sir" in rl
                    or "kontur" in rl
                    or "band" in rl
                ),
                msg=row["reason"],
            )


if __name__ == "__main__":
    unittest.main()
