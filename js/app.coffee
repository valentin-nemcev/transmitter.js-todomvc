'use strict'

{inspect} = require 'util'

$ = require 'jquery'
keycode = require 'keycode'

window.Transmitter = require 'transmitter'


class Todo extends Transmitter.Nodes.Record

  inspect: -> "[Todo #{inspect @labelVar.get()}]"

  init: (tr, defaults = {}) ->
    {label, isCompleted} = defaults
    @labelVar.init(tr, label) if label?
    @isCompletedVar.init(tr, isCompleted) if isCompleted?
    return this

  @defineVar 'labelVar'

  @defineVar 'isCompletedVar'


class TodoView extends Transmitter.Nodes.Record

  inspect: -> "[TodoView #{inspect @todo.labelVar.get()}]"

  constructor: (@todo) ->
    @$element = $('<li/>').append(
      $('<div/>', class: 'view').append(
        $('<input/>', class: 'toggle', type: 'checkbox')
        $('<label/>')
        $('<button/>', class: 'destroy')
      )
      $('<input/>', class: 'edit')
    )


  init: (tr) ->
    @editStateVar.init(tr, off)
    @acceptEditChannel.init(tr)
    @rejectEditChannel.init(tr)
    @editStateChannel = new EditStateChannel(this).init(tr)
    return this


  @defineLazy 'startEditEvt', -> @labelDblclickEvt
  @defineLazy 'acceptEditEvt', -> new Transmitter.Nodes.RelayNode()
  @defineLazy 'rejectEditEvt', -> new Transmitter.Nodes.RelayNode()

  @defineLazy 'acceptEditChannel', ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @inputKeypressEvt
      .toTarget @acceptEditEvt
      .withTransform (msg) ->
        if keycode(msg.get?()) is 'enter'
          Transmitter.Payloads.Variable.setConst(yes)
        else
          Transmitter.Payloads.noop()

  @defineLazy 'rejectEditChannel', ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @inputKeypressEvt
      .toTarget @rejectEditEvt
      .withTransform (msg) ->
        if keycode(msg.get?()) is 'esc'
          Transmitter.Payloads.Variable.setConst(yes)
        else
          Transmitter.Payloads.noop()


  class EditStateChannel extends Transmitter.Channels.CompositeChannel

    constructor: (@todoView) ->

    @defineChannel ->
      new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSource @todoView.startEditEvt
        .toTarget @todoView.editStateVar
        .withTransform (msg) ->
          if msg.map? then msg.map( -> yes) else msg

    @defineChannel ->
      new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSource @todoView.acceptEditEvt
        .toTarget @todoView.editStateVar
        .withTransform (msg) ->
          if msg.map? then msg.map( -> no) else msg

    @defineChannel ->
      new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSource @todoView.rejectEditEvt
        .toTarget @todoView.editStateVar
        .withTransform (msg) ->
          if msg.map? then msg.map( -> no) else msg


  createRemoveTodoChannel: ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @destroyClickEvt
      .withTransform (payload) =>
        if payload.get?
          Transmitter.Payloads.List.removeConst(@todo)
        else
          Transmitter.Payloads.noop()


  @defineLazy 'labelVar', ->
    new Transmitter.DOMElement.TextVar(@$element.find('label')[0])

  @defineLazy 'labelInputVar', ->
    new Transmitter.DOMElement.InputValueVar(@$element.find('.edit')[0])

  @defineLazy 'isCompletedInputVar', ->
    checkbox = @$element.find('.toggle')[0]
    new Transmitter.DOMElement.CheckboxStateVar(checkbox)

  @defineLazy 'labelDblclickEvt', ->
    new Transmitter.DOMElement.DOMEvent(@$element.find('label')[0], 'dblclick')

  @defineLazy 'inputKeypressEvt', ->
    new Transmitter.DOMElement.DOMEvent(@$element.find('.edit')[0], 'keyup')

  @defineLazy 'destroyClickEvt', ->
    new Transmitter.DOMElement.DOMEvent(@$element.find('.destroy')[0], 'click')


  class ClassToggleVar extends Transmitter.Nodes.Variable
    constructor: (@$element, @class) ->
    set: (state) -> @$element.toggleClass(@class, !!state); this
    get: -> @$element.hasClass(@class)


  @defineLazy 'isCompletedClassVar', ->
    new ClassToggleVar(@$element, 'completed')

  @defineLazy 'editStateVar', ->
    new ClassToggleVar(@$element, 'editing')



class TodoViewChannel extends Transmitter.Channels.CompositeChannel

  inspect: ->
    @todo.inspect() + '<->' + @todoView.inspect()


  constructor: (@todo, @todoView) ->


  connect: ->
    console.log 'connect', this.inspect()
    super


  disconnect: ->
    console.log 'disconnect', this.inspect()
    super


  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .withOrigin @todo.labelVar
      .withDerived @todoView.labelVar


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @todoView.labelInputVar
      .fromSource @todoView.acceptEditEvt
      .toTarget @todo.labelVar
      .withTransform (payloads) =>
        label  = payloads.get(@todoView.labelInputVar)
        accept = payloads.get(@todoView.acceptEditEvt)

        if accept.get? then label else accept


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todo.labelVar
      .fromSource @todoView.startEditEvt
      .fromSource @todoView.rejectEditEvt
      .toTarget @todoView.labelInputVar
      .withTransform (payloads) =>
        label  = payloads.get(@todo.labelVar)
        start  = payloads.get(@todoView.startEditEvt)
        reject = payloads.get(@todoView.rejectEditEvt)

        if start.get? or reject.get?
          label
        else
          Transmitter.Payloads.noop()


  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .withOrigin @todo.isCompletedVar
      .withDerived @todoView.isCompletedInputVar


  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .inForwardDirection()
      .withOrigin @todo.isCompletedVar
      .withDerived @todoView.isCompletedClassVar



class TodoListView extends Transmitter.Nodes.Record

  constructor: (@$element) ->

  init: (tr) ->
    @viewElementListChannel.init(tr)

  @defineLazy 'viewList', ->
    new Transmitter.Nodes.List()

  @defineLazy 'elementList', ->
    new Transmitter.DOMElement.ChildrenList(@$element[0])

  @defineLazy 'viewElementListChannel', ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @viewList
      .toTarget @elementList
      .withTransform (views) ->
        views.updateMatching(
          (view) -> view.$element[0]
          (view, element) -> view.$element[0] == element
        )



class TodoListViewChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@todoList, @todoListView) ->


  @defineChannel ->
    removeTodoChannelList = new Transmitter.ChannelNodes.ChannelList()
    new Transmitter.Channels.SimpleChannel()
      .fromSource @todoListView.viewList
      .toConnectionTarget removeTodoChannelList
      .withTransform (todoViews) =>
        todoViews.map (todoView) =>
          todoView.createRemoveTodoChannel().toTarget(@todoList)


  @defineChannel ->
    new Transmitter.Channels.ListChannel()
    .withOrigin @todoList
    .withMapOrigin (todo, tr) -> new TodoView(todo).init(tr)
    .withDerived @todoListView.viewList
    .withMatchOriginDerived (todo, todoView) -> todo == todoView.todo
    .withMatchOriginDerivedChannel (todo, todoView, channel) ->
      channel.todo == todo and channel.todoView == todoView
    .withOriginDerivedChannel (todo, todoView) ->
      if todo? and todoView?
        console.log "new TodoViewChannel(#{todo.inspect()}, #{todoView.inspect()})"
        new TodoViewChannel(todo, todoView)
      else
        Transmitter.Channels.getNullChannel()



class NewTodoView extends Transmitter.Nodes.Record

  constructor: (@$element) ->
    @element = @$element[0]


  init: (tr) ->
    @clearNewTodoLabelInputChannel.init(tr)
    return this


  @defineLazy 'newTodoLabelInputVar', ->
    new Transmitter.DOMElement.InputValueVar(@element)


  @defineLazy 'newTodoKeypressEvt', ->
    new Transmitter.DOMElement.DOMEvent(@element, 'keyup')


  createNewTodoChannel: ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @newTodoLabelInputVar
      .fromSource @newTodoKeypressEvt
      .withTransform (payloads, tr) =>
        label    = payloads.get(@newTodoLabelInputVar)
        keypress = payloads.get(@newTodoKeypressEvt)

        key = keycode(keypress.get?())
        if key is 'enter'
          todo = new Todo().init(tr, label: label.get())
          Transmitter.Payloads.List.appendConst(todo)
        else
          Transmitter.Payloads.noop()


  @defineLazy 'clearNewTodoLabelInputChannel', ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @newTodoKeypressEvt
      .toTarget @newTodoLabelInputVar
      .withTransform (keypress) ->
        key = keycode(keypress.get?())
        if key in ['esc', 'enter']
          Transmitter.Payloads.Variable.setConst('')
        else
          Transmitter.Payloads.noop()



window.todoList = new Transmitter.Nodes.List()
todoList.inspect = -> 'todoList'

window.todoListView = new TodoListView($('.todo-list'))
window.newTodoView = new NewTodoView($('.new-todo'))

todoListViewChannel = new TodoListViewChannel(todoList, todoListView)



Element::inspect = -> '<' + @tagName + ' ... />'
$.Event::inspect = -> '[$Ev ' + @type + ' ... ]'
Event::inspect = -> '[Ev ' + @type + ' ... ]'

# Transmitter.Transmission::loggingFilter = (msg) ->
#   msg.match(/elementList|viewList|todoList/)

Transmitter.Transmission::loggingIsEnabled = no

Transmitter.startTransmission (tr) ->
  todoListView.init(tr)
  todoListViewChannel.init(tr)
  newTodoView.init(tr)
  newTodoView.createNewTodoChannel().toTarget(todoList).init(tr)

  todo1 = new Todo().init(tr, label: 'Todo 1')
  todo2 = new Todo().init(tr, label: 'Todo 2', isCompleted: yes)

  todoList.init(tr, [todo1, todo2])
