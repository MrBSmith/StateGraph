# State

An abstract base class for a State in a StateMachine

<br>

Defines the behaviour of the entity possesing the `StateMachine` when the entity is in this state.
You can inherit it to make your own state logic, or use it as is, in conjonction with an `AnimationStateHandler` if you just want to make an animation StateMachine

If you want to manage the state transitions via the StateGraph tool, be sure to make every State script you create a `tool`, so be cautious about what code runs in the editor.
Please read the Godot's article [here](https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html) if you don't know what tool keyword is for.

<br>


### Properties

`Array connexions_array`

An Array of `Dictionary` containing data about the connexions between this state and others.
See StateGraph for more information on how connexions work.

<br>

`Dictionary standalone_trigger`

A Dictionary containing data about this state's standalone_trigger.
See StateGraph for more information on how standalone_trigger work.

<br>

`Vector2 graph_position`

Defines the position of the StateNode in the StateGraph. Expressed in ratio of the container size.

<br>

`StateMachine states_machine`

A reference to the parent of this State -its StateMachine.
This property will be null if the parent of this State isn't a StateMachine.


### Signals

`standalone_trigger_added()`

Emitted when a standalone_trigger is added to this state. (Only emitted in the editor)
 

<br>

`standalone_trigger_removed()`

Emitted when a standalone_trigger is removed from this state. (Only emitted in the editor)

<br>

### Callbacks


`void enter_state()`

A virtual method, called by its `StateMachine` parent every time the state is beeing entered.
Override it with your own logic that must be called when this state starts.

<br>

`void exit_state()`

A virtual method, called by its `StateMachine` parent every time the state is beeing exited.
Override it with your own logic that must be called when this state ends.

<br>

`void update_state(delta: float)`

A virtual method, called by its `StateMachine` parent's `_physics_process()`.
Override it with your own gameplay/physics logic.

<br>


### Methods

`bool is_current_state()`

Returns true if the StateMachine is in this state. Check reccursivly in case of nested StateMachines/PushdownAutomata


