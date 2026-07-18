"""Verify Gloom Weed gold double + buff visibility rules (pure logic)."""
from __future__ import annotations


def gloom_weed_doubles_gold(cauldron_ids: list[str]) -> bool:
	if not cauldron_ids:
		return False
	return cauldron_ids[-1] == "gloom_weed"


def gold_reward(score: int, bonus_gold: int, cauldron_ids: list[str]) -> int:
	base = score if score <= 14 else 14 + (score - 14) // 2
	total = base + bonus_gold
	if gloom_weed_doubles_gold(cauldron_ids):
		total *= 2
	return total


def buff_visible(cauldron_ids: list[str]) -> bool:
	# Icon should track the same condition as gold double.
	return gloom_weed_doubles_gold(cauldron_ids)


def main() -> int:
	assert not gloom_weed_doubles_gold([])
	assert gloom_weed_doubles_gold(["gloom_weed"])
	assert not gloom_weed_doubles_gold(["gloom_weed", "chicken"])
	assert gloom_weed_doubles_gold(["chicken", "gloom_weed"])
	assert gloom_weed_doubles_gold(["gloom_weed", "gloom_weed"])

	assert buff_visible(["gloom_weed"])
	assert not buff_visible(["gloom_weed", "chicken"])
	assert buff_visible(["chicken", "gloom_weed"])

	with_gloom = gold_reward(10, 2, ["gloom_weed"])
	without = gold_reward(10, 2, ["chicken"])
	assert with_gloom == without * 2, (with_gloom, without)

	print("PASS: gloom weed gold double + buff visibility rules")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
