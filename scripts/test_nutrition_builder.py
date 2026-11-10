import math
import unittest
from build_nutrition_catalog import convert, energy


def food(values, data_type="Foundation"):
    return dict(dataType=data_type, description="Chicken, raw", fdcId=1,
                foodNutrients=[dict(nutrient=dict(id=i, unitName=u), amount=v) for i, u, v in values])


class BuilderTests(unittest.TestCase):
    def test_chooses_specific_then_general_then_legacy_never_sums(self):
        self.assertEqual(energy(food([(1008, "kcal", 100), (2047, "kcal", 110), (2048, "kcal", 120)])), (120, 2048))
        self.assertEqual(energy(food([(2047, "kcal", 110)])), (110, 2047))
        self.assertEqual(energy(food([(1008, "kcal", 100)], "SR Legacy")), (100, 1008))

    def test_missing_invalid_energy_is_not_zero_and_kilojoules_are_not_kcal(self):
        for values in [[], [(1008, "kJ", 300)], [(1008, "kcal", -1)], [(1008, "kcal", math.nan)],
                       [(1008, "kcal", math.inf)], [(1008, "kcal", 1001)]]:
            self.assertIsNone(energy(food(values)))
        self.assertEqual(energy(food([(1008, "kcal", 0)])), (0, 1008))

    def test_source_identity_and_preparation_are_preserved(self):
        row = convert(food([(1008, "kcal", 120)]), "test-release")
        self.assertEqual(row["id"], "fdc-1")
        self.assertEqual(row["preparation"], "raw")
        self.assertEqual(row["release"], "test-release")
        self.assertEqual(row["sourceURL"], "https://fdc.nal.usda.gov/food-details/1/nutrients")


if __name__ == "__main__":
    unittest.main()
