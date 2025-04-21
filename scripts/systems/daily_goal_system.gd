extends Node
## Manages daily goals and achievements to give players short-term objectives
## Add this script to an autoload in the Project Settings

# Signals
signal daily_goals_reset
signal goal_progress_updated(goal_id, current, target)
signal goal_completed(goal_id)
signal achievement_unlocked(achievement_id)

# Goal Templates
const GOAL_TEMPLATES = [
	{
		"type": "gather_ingredients",
		"title_template": "Gather Ingredients",
		"description_template": "Gather {target} ingredients from any source",
		"min_target": 3,
		"max_target": 10,
		"difficulty": 1,
		"reward_gold_base": 5,
		"reward_gold_per_target": 2
	},
	{
		"type": "gather_specific",
		"title_template": "Gather {ingredient_name}",
		"description_template": "Gather {target} {ingredient_name} from the {location}",
		"min_target": 2,
		"max_target": 5,
		"difficulty": 2,
		"reward_gold_base": 8,
		"reward_gold_per_target": 3
	},
	{
		"type": "brew_potions",
		"title_template": "Brew Potions",
		"description_template": "Brew {target} potions of any type",
		"min_target": 2,
		"max_target": 5,
		"difficulty": 1,
		"reward_gold_base": 10,
		"reward_gold_per_target": 5
	},
	{
		"type": "brew_specific",
		"title_template": "Brew {potion_name}",
		"description_template": "Brew {target} {potion_name}",
		"min_target": 1,
		"max_target": 3,
		"difficulty": 3,
		"reward_gold_base": 15,
		"reward_gold_per_target": 8
	},
	{
		"type": "complete_orders",
		"title_template": "Complete Villager Orders",
		"description_template": "Complete {target} orders from any villager",
		"min_target": 1,
		"max_target": 3,
		"difficulty": 2,
		"reward_gold_base": 20,
		"reward_gold_per_target": 10,
		"reward_essence": 1
	},
	{
		"type": "experiment",
		"title_template": "Experimental Brewing",
		"description_template": "Perform {target} experimental brews",
		"min_target": 2,
		"max_target": 5,
		"difficulty": 2,
		"reward_gold_base": 12,
		"reward_gold_per_target": 4,
		"reward_essence": 1
	},
	{
		"type": "quality",
		"title_template": "Quality Crafting",
		"description_template": "Brew {target} potions with quality above 1.2",
		"min_target": 1,
		"max_target": 3,
		"difficulty": 3,
		"reward_gold_base": 25,
		"reward_gold_per_target": 8,
		"reward_essence": 1
	}
]

# Achievements
const ACHIEVEMENTS = {
	"first_potion": {
		"title": "First Brew",
		"description": "Brew your first potion",
		"hidden": false,
		"reward_gold": 10,
		"requirement": 1
	},
	"potion_master": {
		"title": "Potion Master",
		"description": "Brew 50 potions",
		"hidden": false,
		"reward_gold": 100,
		"reward_essence": 5,
		"requirement": 50
	},
	"recipe_collector": {
		"title": "Recipe Collector",
		"description": "Discover 10 different recipes",
		"hidden": false,
		"reward_gold": 50,
		"reward_essence": 2,
		"requirement": 10
	},
	"ingredient_hoarder": {
		"title": "Ingredient Hoarder",
		"description": "Collect 100 ingredients",
		"hidden": false,
		"reward_gold": 50,
		"requirement": 100
	},
	"villager_friend": {
		"title": "Village Hero",
		"description": "Complete 20 villager orders",
		"hidden": false,
		"reward_gold": 100,
		"reward_essence": 3,
		"requirement": 20
	},
	"max_quality": {
		"title": "Perfect Brew",
		"description": "Create a potion with 2.0 quality",
		"hidden": true,
		"reward_gold": 200,
		"reward_essence": 5,
		"requirement": 1
	}
}

# Private variables
var _active_goals = []  # Daily goals currently active
var _goal_progress = {}  # Progress tracking for goals
var _unlocked_achievements = []  # List of unlocked achievement IDs
var _achievement_progress = {}  # Progress tracking for achievements

# Lifecycle methods
func _ready():
	# Connect to game systems
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.game_day_passed.connect(_on_game_day_passed)
	
	var recipe_manager = get_node_or_null("/root/RecipeManager")
	if recipe_manager:
		recipe_manager.recipe_discovered.connect(_on_recipe_discovered)
	
	var villager_manager = get_node_or_null("/root/VillagerManager")
	if villager_manager:
		villager_manager.order_completed.connect(_on_order_completed)
	
	# Initialize achievement progress
	for achievement_id in ACHIEVEMENTS:
		if not _achievement_progress.has(achievement_id):
			_achievement_progress[achievement_id] = 0
	
	# Generate initial daily goals if none exist
	if _active_goals.empty():
		_generate_daily_goals()

# Public methods
func get_active_goals():
	"""Returns all active daily goals"""
	return _active_goals.duplicate(true)

func get_goal_progress(goal_id):
	"""Returns progress for a specific goal"""
	if _goal_progress.has(goal_id):
		return _goal_progress[goal_id]
	return 0

func update_goal_progress(goal_id, progress):
	"""
	Updates progress for a specific goal
	Returns true if goal is now complete
	"""
	# Find the goal
	var goal = null
	for g in _active_goals:
		if g.id == goal_id:
			goal = g
			break
	
	if not goal or goal.completed:
		return false
	
	# Update progress
	if not _goal_progress.has(goal_id):
		_goal_progress[goal_id] = 0
	
	var old_progress = _goal_progress[goal_id]
	var new_progress = min(progress, goal.target)
	_goal_progress[goal_id] = new_progress
	
	# Check if progress changed
	if new_progress != old_progress:
		goal_progress_updated.emit(goal_id, new_progress, goal.target)
	
	# Check if goal is now complete
	if new_progress >= goal.target and not goal.completed:
		goal.completed = true
		_award_goal_rewards(goal)
		goal_completed.emit(goal_id)
		return true
	
	return false

func increment_goal_progress(goal_type, amount=1, specific_id=""):
	"""
	Increments progress for all goals matching the specified type
	If specific_id is provided, only affects goals with that specific ID
	Returns the number of goals updated
	"""
	var updated_count = 0
	
	for goal in _active_goals:
		if goal.completed:
			continue
			
		if goal.type == goal_type:
			# For specific goals, check the specific ID
			if goal.type == "gather_specific" and specific_id != "":
				if goal.has("ingredient_id") and goal.ingredient_id != specific_id:
					continue
			elif goal.type == "brew_specific" and specific_id != "":
				if goal.has("potion_id") and goal.potion_id != specific_id:
					continue
			
			# Update progress
			if not _goal_progress.has(goal.id):
				_goal_progress[goal.id] = 0
			
			var new_progress = _goal_progress[goal.id] + amount
			if update_goal_progress(goal.id, new_progress):
				updated_count += 1
	
	return updated_count

func get_unlocked_achievements():
	"""Returns all unlocked achievements"""
	var result = []
	for achievement_id in _unlocked_achievements:
		if ACHIEVEMENTS.has(achievement_id):
			var achievement = ACHIEVEMENTS[achievement_id].duplicate()
			achievement.id = achievement_id
			result.append(achievement)
	
	return result

func get_achievement_progress(achievement_id):
	"""Returns progress for a specific achievement"""
	if _achievement_progress.has(achievement_id):
		return _achievement_progress[achievement_id]
	return 0

func update_achievement_progress(achievement_id, progress):
	"""
	Updates progress for a specific achievement
	Returns true if achievement is now unlocked
	"""
	if not ACHIEVEMENTS.has(achievement_id) or _unlocked_achievements.has(achievement_id):
		return false
	
	var achievement = ACHIEVEMENTS[achievement_id]
	
	# Update progress
	if not _achievement_progress.has(achievement_id):
		_achievement_progress[achievement_id] = 0
	
	var old_progress = _achievement_progress[achievement_id]
	var new_progress = progress
	_achievement_progress[achievement_id] = new_progress
	
	# Check if achievement is now unlocked
	if new_progress >= achievement.requirement and not _unlocked_achievements.has(achievement_id):
		_unlocked_achievements.append(achievement_id)
		_award_achievement_rewards(achievement_id)
		achievement_unlocked.emit(achievement_id)
		return true
	
	return false

func increment_achievement_progress(achievement_id, amount=1):
	"""
	Increments progress for a specific achievement
	Returns true if achievement is now unlocked
	"""
	if not ACHIEVEMENTS.has(achievement_id) or _unlocked_achievements.has(achievement_id):
		return false
	
	var new_progress = get_achievement_progress(achievement_id) + amount
	return update_achievement_progress(achievement_id, new_progress)

func get_save_data():
	"""Returns a dictionary with all data needed to save goal and achievement state"""
	return {
		"active_goals": _active_goals,
		"goal_progress": _goal_progress,
		"unlocked_achievements": _unlocked_achievements,
		"achievement_progress": _achievement_progress
	}

func load_save_data(data):
	"""Loads goal and achievement state from saved data"""
	if data.has("active_goals"):
		_active_goals = data.active_goals.duplicate(true)
	
	if data.has("goal_progress"):
		_goal_progress = data.goal_progress.duplicate(true)
	
	if data.has("unlocked_achievements"):
		_unlocked_achievements = data.unlocked_achievements.duplicate()
	
	if data.has("achievement_progress"):
		_achievement_progress = data.achievement_progress.duplicate(true)

# Private methods
func _generate_daily_goals():
	"""Generates a new set of daily goals"""
	# Clear current goals and progress
	_active_goals.clear()
	_goal_progress.clear()
	
	# Determine number of goals based on player level
	var player_level = 1
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		player_level = game_manager.player_level
	
	var num_goals = 3  # Base number
	if player_level >= 5:
		num_goals = 4
	if player_level >= 10:
		num_goals = 5
	
	# Create goals of varied difficulty
	var templates = GOAL_TEMPLATES.duplicate()
	templates.shuffle()
	
	for i in range(min(num_goals, templates.size())):
		var template = templates[i]
		var goal = _create_goal_from_template(template)
		_active_goals.append(goal)
		_goal_progress[goal.id] = 0
	
	# Signal that goals were reset
	daily_goals_reset.emit()

func _create_goal_from_template(template):
	"""Creates a specific goal based on a template"""
	var goal_id = "goal_" + template.type + "_" + str(Time.get_unix_time_from_system())
	
	# Determine target based on difficulty
	var target = randi_range(template.min_target, template.max_target)
	
	# Calculate reward
	var reward = {
		"gold": template.reward_gold_base + (template.reward_gold_per_target * target)
	}
	
	# Add essence for higher difficulty goals
	if template.difficulty >= 2 and template.has("reward_essence"):
		reward.essence = template.reward_essence
	
	# Create basic goal structure
	var goal = {
		"id": goal_id,
		"type": template.type,
		"title": template.title_template,
		"description": template.description_template,
		"target": target,
		"difficulty": template.difficulty,
		"reward": reward,
		"completed": false
	}
	
	# Handle specific goal types that need additional processing
	match template.type:
		"gather_specific":
			_setup_specific_gathering_goal(goal)
		"brew_specific":
			_setup_specific_brewing_goal(goal)
	
	return goal

func _setup_specific_gathering_goal(goal):
	"""Sets up a goal for gathering a specific ingredient"""
	var ingredient_manager = get_node_or_null("/root/IngredientManager")
	if not ingredient_manager:
		return
	
	# Get all available ingredients
	var all_ingredients = ingredient_manager.get_all_ingredient_ids()
	if all_ingredients.empty():
		return
	
	# Choose a random ingredient
	var ingredient_id = all_ingredients[randi() % all_ingredients.size()]
	var ingredient = ingredient_manager.get_ingredient(ingredient_id)
	if not ingredient:
		return
	
	# Determine location based on category
	var location = "garden"
	if ingredient.category == "mineral_elements":
		location = "forest"
	elif ingredient.category == "special_elements":
		location = "special locations"
	
	# Store ingredient info in the goal
	goal.ingredient_id = ingredient_id
	goal.ingredient_name = ingredient.name
	goal.location = location
	
	# Update title and description with actual values
	goal.title = goal.title.replace("{ingredient_name}", ingredient.name)
	goal.description = goal.description.replace("{ingredient_name}", ingredient.name)
	goal.description = goal.description.replace("{location}", location)
	goal.description = goal.description.replace("{target}", str(goal.target))

func _setup_specific_brewing_goal(goal):
	"""Sets up a goal for brewing a specific potion"""
	var recipe_manager = get_node_or_null("/root/RecipeManager")
	if not recipe_manager:
		return
	
	# Get all discovered recipes
	var discovered_recipes = recipe_manager.get_discovered_recipes()
	if discovered_recipes.empty():
		return
	
	# Choose a random recipe
	var recipe_id = discovered_recipes[randi() % discovered_recipes.size()]
	var recipe = recipe_manager.get_recipe(recipe_id)
	if not recipe:
		return
	
	var potion_id = recipe.result_id
	var potion = recipe_manager.get_potion(potion_id)
	if not potion:
		return
	
	# Store potion info in the goal
	goal.potion_id = potion_id
	goal.recipe_id = recipe_id
	goal.potion_name = potion.name
	
	# Update title and description with actual values
	goal.title = goal.title.replace("{potion_name}", potion.name)
	goal.description = goal.description.replace("{potion_name}", potion.name)
	goal.description = goal.description.replace("{target}", str(goal.target))

func _award_goal_rewards(goal):
	"""Awards rewards for completing a goal"""
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return
	
	var notification_system = get_node_or_null("/root/NotificationSystem")
	
	# Award gold
	if goal.reward.has("gold"):
		game_manager.add_gold(goal.reward.gold)
	
	# Award essence
	if goal.reward.has("essence"):
		game_manager.add_essence(goal.reward.essence)
	
	# Show notification
	if notification_system:
		var reward_text = ""
		if goal.reward.has("gold"):
			reward_text += str(goal.reward.gold) + " gold"
		if goal.reward.has("essence"):
			if reward_text.length() > 0:
				reward_text += ", "
			reward_text += str(goal.reward.essence) + " essence"
		
		notification_system.show_success("Goal Completed: " + goal.title + "\nReward: " + reward_text, 4.0)

func _award_achievement_rewards(achievement_id):
	"""Awards rewards for unlocking an achievement"""
	if not ACHIEVEMENTS.has(achievement_id):
		return
	
	var achievement = ACHIEVEMENTS[achievement_id]
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return
	
	var notification_system = get_node_or_null("/root/NotificationSystem")
	
	# Award gold
	if achievement.has("reward_gold"):
		game_manager.add_gold(achievement.reward_gold)
	
	# Award essence
	if achievement.has("reward_essence"):
		game_manager.add_essence(achievement.reward_essence)
	
	# Show notification
	if notification_system:
		var reward_text = ""
		if achievement.has("reward_gold"):
			reward_text += str(achievement.reward_gold) + " gold"
		if achievement.has("reward_essence"):
			if reward_text.length() > 0:
				reward_text += ", "
			reward_text += str(achievement.reward_essence) + " essence"
		
		notification_system.show_success("Achievement Unlocked: " + achievement.title + "\n" + achievement.description + "\nReward: " + reward_text, 5.0)

# Signal handlers
func _on_game_day_passed(_day_number):
	"""Called when a game day passes"""
	_generate_daily_goals()

func _on_resource_gathered(resource_id, quantity, _quality):
	"""Called when a resource is gathered"""
	# Update gathering goals
	increment_goal_progress("gather_ingredients", quantity)
	increment_goal_progress("gather_specific", quantity, resource_id)
	
	# Update achievement progress
	increment_achievement_progress("ingredient_hoarder", quantity)

func _on_brewing_completed(potion_id, _potion_name, quality):
	"""Called when brewing is completed"""
	# Update brewing goals
	increment_goal_progress("brew_potions", 1)
	increment_goal_progress("brew_specific", 1, potion_id)
	
	# Update achievement progress
	increment_achievement_progress("first_potion", 1)
	increment_achievement_progress("potion_master", 1)
	
	# Check for quality achievements
	if quality >= 2.0:
		update_achievement_progress("max_quality", 1)
	
	# Update quality goals
	if quality >= 1.2:
		increment_goal_progress("quality", 1)

func _on_order_completed(_order_id, _villager_id):
	"""Called when a villager order is completed"""
	# Update order completion goals
	increment_goal_progress("complete_orders", 1)
	
	# Update achievement progress
	increment_achievement_progress("villager_friend", 1)

func _on_recipe_discovered(_recipe_id):
	"""Called when a recipe is discovered"""
	# Update achievement progress
	var recipe_manager = get_node_or_null("/root/RecipeManager")
	if recipe_manager:
		var discovered_count = recipe_manager.get_discovered_recipes().size()
		update_achievement_progress("recipe_collector", discovered_count)

func _on_experimental_brew(_success):
	"""Called when an experimental brew is performed"""
	# Update experimental brewing goals
	increment_goal_progress("experiment", 1)
