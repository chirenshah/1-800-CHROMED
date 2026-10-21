extends RefCounted
class_name SalesSlamPlan
## Pure Sales Slam rules: ordering, intensity, pacing, tension stages, and the goal-breaking sale.
## It never touches game state or UI, so the tally can be replayed and tested in isolation.

enum Outcome { SHORT, REACHED, EXCEEDED }
enum Stage { IDLE, WARM, HOT, STRAINED, REACHED, EXCEEDED }

var reference_sale_value := 500.0
var min_intensity := 0.1
var max_intensity := 1.0
## Rhythm: light sales take one beat, heavy sales take two, so the tally has a steady pulse.
var beat_seconds := 0.2
var heavy_intensity := 0.7
## Steps speed up toward the strain threshold (drum roll), down to this fraction of a beat.
var accel_floor := 0.55
## Steps between strain and the goal stretch out so the player can anticipate the crossing.
var anticipation_stretch := 1.45
## Hold before the goal-breaking sale lands.
var windup_seconds := 0.45
## Extra dramatic silence before revealing a near miss.
var near_miss_pause_seconds := 0.6
var goal_break_seconds := 1.0
var final_reveal_seconds := 0.5
## Typical-day target; long days are compressed toward it instead of running unbounded.
var max_total_seconds := 5.0
var min_step_seconds := 0.01
## Ratios of goal for subtle, increased, and warning feedback.
var stage_thresholds: Array[float] = [0.5, 0.75, 0.9]
var near_miss_ratio := 0.9


func intensity(value: int) -> float:
	var ratio := maxf(float(value), 0.0) / maxf(reference_sale_value, 0.001)
	return clampf(sqrt(ratio), min_intensity, max_intensity)


func total(sales: Array) -> int:
	var sum := 0
	for sale: Dictionary in sales:
		sum += maxi(int(sale.get("value", 0)), 0)
	return sum


## Ascending by value; ties keep recorded order so replays are deterministic.
func sort_sales(sales: Array) -> Array[Dictionary]:
	var indexed: Array[Dictionary] = []
	for index in sales.size():
		var sale: Dictionary = (sales[index] as Dictionary).duplicate()
		sale["value"] = maxi(int(sale.get("value", 0)), 0)
		sale["seq"] = index
		indexed.append(sale)
	indexed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["value"] != b["value"]:
			return a["value"] < b["value"]
		return a["seq"] < b["seq"])
	return indexed


func stage_for(tally: int, goal: int) -> int:
	if tally > goal:
		return Stage.EXCEEDED
	if tally == goal:
		return Stage.REACHED
	var ratio := float(tally) / float(goal)
	if ratio >= stage_thresholds[2]:
		return Stage.STRAINED
	if ratio >= stage_thresholds[1]:
		return Stage.HOT
	if ratio >= stage_thresholds[0]:
		return Stage.WARM
	return Stage.IDLE


func outcome(total_revenue: int, goal: int) -> int:
	if total_revenue > goal:
		return Outcome.EXCEEDED
	return Outcome.REACHED if total_revenue == goal else Outcome.SHORT


func is_near_miss(total_revenue: int, goal: int) -> bool:
	return goal > 0 and total_revenue < goal and float(total_revenue) / float(goal) >= near_miss_ratio


## One step per sale. Exactly the sale that carries the tally past the goal has breaks_goal.
func build(sales: Array, goal: int) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var tally := 0
	var normal_seconds := 0.0
	var breaks_seen := false
	for sale in sort_sales(sales):
		var before := tally
		tally += int(sale["value"])
		var heat := intensity(int(sale["value"]))
		var breaks := not breaks_seen and before <= goal and tally > goal
		breaks_seen = breaks_seen or breaks
		var seconds := goal_break_seconds if breaks else step_seconds(heat, before, goal)
		if not breaks:
			normal_seconds += seconds
		steps.append({
			"index": steps.size(), "value": sale["value"], "employee_id": sale.get("employee_id", ""),
			"tally_before": before, "tally_after": tally, "stage": stage_for(tally, goal),
			"intensity": heat, "duration": seconds, "breaks_goal": breaks,
			"windup": windup_seconds if breaks else 0.0,
		})
	var budget := max_total_seconds - final_reveal_seconds
	if breaks_seen:
		budget -= goal_break_seconds + windup_seconds
	if normal_seconds > budget and normal_seconds > 0.0:
		var scale := maxf(budget, 0.0) / normal_seconds
		for step in steps:
			if not step["breaks_goal"]:
				step["duration"] = maxf(float(step["duration"]) * scale, min_step_seconds)
	return steps


## Beat-grid duration for an ordinary sale, accelerating toward the strain threshold and
## stretching again just before the goal.
func step_seconds(heat: float, tally_before: int, goal: int) -> float:
	var beats := 2.0 if heat >= heavy_intensity else 1.0
	var ratio := float(tally_before) / float(goal) if goal > 0 else 1.0
	var strain: float = stage_thresholds[2]
	var speed := lerpf(1.0, accel_floor, clampf(ratio / strain, 0.0, 1.0))
	var seconds := beats * beat_seconds * speed
	if ratio >= strain and tally_before <= goal:
		seconds *= anticipation_stretch
	return maxf(seconds, min_step_seconds)


func total_seconds(steps: Array[Dictionary]) -> float:
	var seconds := final_reveal_seconds
	for step in steps:
		seconds += float(step["duration"]) + float(step.get("windup", 0.0))
	return seconds
