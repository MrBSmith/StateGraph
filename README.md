<img src="https://user-images.githubusercontent.com/34774144/172344454-a01503ce-8cf5-40f8-9d0f-5da0fe3ee189.svg" width="500" align="middle">


A Godot plugin that manages state machines &amp; state transitions.


It features:
- A StateMachine based on nodes
- Nested StateMachines
- Pushdown Automatas
- Automatic animation triggering directly AnimatedSprite
- A powerful GraphEditor to handle state transitions
- State change based on signals and/or as many conditions you want

<br>

This addon is under MIT license which means its free to use/copy/modify etc.
If you want to help financally its creator, you can tip him [here](https://ko-fi.com/babadesbois)


<br>

# 💾 Install 💾

You can either:

- Browse for StateGraph in the AssetLib tab inside Godot, and install it from there, using the Godot's plugin install interface.
- Clone this repo in a folder `addons/StateGraph` a the root of your project; then activate the plugin in ProjectSettings -> Plugins

<br>

# 📃 Documentation 📃

You can find a detailed, by class documentation, as well as a tutorial on how to use the **GraphEditor** [here](https://github.com/MrBSmith/StateGraph/wiki).

<br>

# 🕵️ Overview 🕵️


## Basic use

**StateGraph** is an implementation of the **[State](https://refactoring.guru/design-patterns/state)** -also known as **Finite State Machine**- design pattern. 

It uses basically two types of nodes: a [StateMachine](https://github.com/MrBSmith/StateGraph/wiki/StateMachine) node that handles its [State](https://github.com/MrBSmith/StateGraph/wiki/State) children, like in this exemple bellow.

![image](https://user-images.githubusercontent.com/34774144/168663500-d85902a7-96de-4b74-87e6-ab8953ec8081.png)

You can inherit the [State](https://github.com/MrBSmith/StateGraph/wiki/State) class to associate it with your own logic, or just use basic [State](https://github.com/MrBSmith/StateGraph/wiki/State) nodes if you are doing a [StateMachine](https://github.com/MrBSmith/StateGraph/wiki/StateMachine) dedicated to animation for exemple.

If you inherit the [State](wiki/State) class, be aware that your scripts must have the `tool` keyword for it to work with the [GraphEditor](https://github.com/MrBSmith/StateGraph/wiki/GraphEditor).
You can find more informations about how to use the [State](https://github.com/MrBSmith/StateGraph/wiki/State) class and every others in the [Documentation](https://github.com/MrBSmith/StateGraph/wiki).

<br>

## Graph Editor

The [GraphEditor](https://github.com/MrBSmith/StateGraph/wiki/GraphEditor) is a tool that runs inside the Godot's editor and allows you to manage & edit the **connexions** between states as well as **standalone triggers**.

Connexions can be triggered either by signals or in the `_physics_process()` of the [StateMachine](https://github.com/MrBSmith/StateGraph/wiki/StateMachine).
Additionaly it can take any amount of conditions that must all return true for the change of state to operate.

The graph also implements **standalone triggers** that works exacly as connexions, but does not need to be in a particular state to trigger.

It is designed to be very flexible and to keep the graph as readable as possible, by minimising the number of connexions you need to make between two states.
If it is correcly used, it will prevent you from writing any boilerplate state transition code. (You can still do it by code tho)

<br>

![image](https://user-images.githubusercontent.com/34774144/168672838-53596f4f-8516-4f88-906d-97b274e2860a.png)






