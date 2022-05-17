# StateMachines

An implementation of the State -or Finite State Machine- design pattern.
Each state is represented by a node, inheriting the `State` class and must be a child node of a StateMachine node.

This class is responsible for keeping trace of the state the entity is in, executing the States `enter_state`, `exit_state` & `update_state` callbacks, 
and triggering the States connexions & standalone_triggers.
(see the `StateGraph` tutorial for more information on these).

Each state defines the behaviour of the entity possesing this StateMachine when the entity is in this state.

The default state is always the first child of this node, unless default_state_path property has a value.

States Machines can also be nested.

In that case the StateMachine behave also as a State, and the enter_state callback is called recursivly.
Note that nested StateMachines that are not the current_state of their parent should have their current_state to null.
That is why the exit_state function of the StateMachine is setting the current state to null.


## Properties

`NodePath default_state_path`

An exported property that define the path to the default state node. 
The given path must lead to a State that is a direct child of its StateMachine.
If this property has an empty NodePath value the frist child of the StateMachine will be considered the default state.

`bool no_default_state`

An exported property. Set this to true if you want the default state to be null, no matter what the default_state_path value is.

`State current_state`

The state the StateMachine currently is in.

`State previous_state`

The state the StateMachine previously was in.


`Array standalone_triggers_states`

Contains the reference of the states that have a standalone trigger


`bool reset_to_default`

An exported property.
Usefull only if this instance of StateMachine is nested (ie its parent is also a StateMachine).
When this state is entered, if this bool is true, reset the child state to the default one.


---

## Signals


`state_entered(State state)`

Emitted when a state is beeing entered. Emitted right before calling the `enter_state()` callback of the state.


`state_entered_recursive(State state)`

Emitted when a state is beeing entered or when of of its children State is entered (recursively).
Emitted right before calling the `enter_state()` callback of the state.

`state_exited(State state)`

Emitted when a state is beeing exited. Emitted right before calling the `exit_state()` callback of the state.

`state_changing(State form_state, State to_state)`

Emitted when the state has changed; emitted after the exit_state of the previous state and before the enter_state of the new state.


`state_added(State state)`

Emitted when a State is added in the scene tree as a child of this StateMachine. Emitted only in the editor.


`state_removed(State state)`

Emitted when a State is removed from the scene tree as a child of this StateMachine. Emitted only in the editor.


---

## Methods

`State get_state()`

Returns the current state

`String get_state_name()`

Returns the name of the current state, or an empty string if the current state is null.


`String set_state(state)`

Change the current state to the given one.
You can give to this function, either the reference to the state you want to go in, or a String reprensenting its name.


`void set_state_by_id(int id)`

Set the state based on the id of the state (id of the node, ie position in the hierachy)


`State get_state_by_name(String state_name)`

Returns the reference of a child State of this StateMachine with the given state_name. 
Returns null if no corresponding State exists.


`bool has_state(String state_name)`

Returns true if this StateMachine have a State named state_name.


`void fetch_states(Array array, bool recursive = false)`

Fills the given array with all the states children of this StateMachine.
If the recursive argument is true, this function will fetch states recursively, meaning also nested states.


`bool is_nested()`

Returns true if this StateMachine is a child of another StateMachine.


`void increment_state(int increment = 1, bool wrapping = true)`

Set the current_state by incrementing its id (id of the node, ie position in the hierachy)
If the wrapping argument is true, and the current_state was the last one, wrap back to the first one.


`StateAnimationHandler get_animation_handler()`

Returns the first StateAnimationHandler it finds as a child of this StateMachine.


`void enter_state()`

Override of the virtual method of the `State` class. Applies only if this StateMachine is nested (If its a child of another StateMachine).
Resets the state to the default_state if the reset_to_default property is true, or if the current_state is null.
Else: calls the enter_state() of the current state again.


`void exit_state()`

Override of the virtual method of the `State` class. Applies only if this StateMachine is nested (If its a child of another StateMachine).
Sets the current_state to null.


`void update_state(float delta)`

Override of the virtual method of the `State` class. Applies only if this StateMachine is nested (If its a child of another StateMachine).
Call the update_state of the current_state


`bool is_current_state()`

Override of the virtual method of the `State` class. Applies only if this StateMachine is nested (If its a child of another StateMachine).
Check if this StateMachine is the current_state of its parent, and its parent of it own parent, recursively.



