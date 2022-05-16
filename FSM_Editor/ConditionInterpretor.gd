extends Object
class_name ConditionInterpretor

const CONDITION_TEMPLATE = """extends Node
var target : Node
func condition() -> bool: return %s"""

const OPERATORS = ["<", ">=", "<=", ">", "==", "!=", "&&", "and", "||", "or", "not", "!"]

#### ACCESSORS ####



#### BUILT-IN ####



#### VIRTUALS ####



#### LOGIC ####

static func inquire_condition(user_condition: String, target: Node) -> bool:
	var cond_script = GDScript.new()
	
	var word_array = user_condition.split(" ")
	
	for i in range(word_array.size()):
		var word = word_array[i]
		
		if word in OPERATORS:
			continue
		
		var word_sub_parts = word.split(".")
		var sub_word = word_sub_parts[0]
		word_sub_parts.remove(0)
		
		var sufix = "." + word_sub_parts.join(".") if !word_sub_parts.empty() else ""
		
		var prefix = ""
		if sub_word[0] in ["!"]:
			prefix = sub_word[0]
			sub_word.erase(0, 1)
		
		var member_name = sub_word.split("(")[0]
		
		if member_name in target or target.has_method(member_name) or target.get(member_name) != null:
			var new_word = prefix + "target." + sub_word + sufix
			word_array[i] = new_word
	
	var condition = word_array.join(" ")
	var code = CONDITION_TEMPLATE % condition
	
	cond_script.source_code = code
	
	var node = Node.new()
	cond_script.reload(true)
	node.set_script(cond_script)
	node.target = target
	
	return node.condition()


#### INPUTS ####



#### SIGNAL RESPONSES ####
