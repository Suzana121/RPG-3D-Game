class_name QuestStage
extends Resource

## Use gaps (10, 20, 30) so stages can be inserted later.
@export var stage_id: int = 10
## Shown in the HUD / journal while this stage is active.
@export_multiline var objective_text: String = ""
## Not empty: when ALL are met, the quest moves to next_stage automatically.
## Empty: the stage only advances when something calls set_stage (e.g. dialogue).
@export var conditions: Array[GameCondition] = []
@export var next_stage: int = -1
## Run once when the quest enters this stage.
@export var on_enter_actions: Array[GameAction] = []
## Entering this stage completes the quest.
@export var completes_quest: bool = false
