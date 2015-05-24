'use strict'

$ = require 'jquery'
keycode = require 'keycode'

Transmitter = require 'transmitter'


class Todo extends Transmitter.Nodes.Record

  @defineVar 'labelVar'

  @defineVar 'isCompletedVar'


class TodoView extends Transmitter.Nodes.Record

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
    @editStateVar.updateState(tr, off)
    @startEditChannel.connect(tr)
    @completeEditChannel.connect(tr)
    return this


  @defineLazy 'startEditChannel', ->
   new Transmitter.Channels.SimpleChannel()
     .fromSource @labelDblclickEvt
     .toTarget @editStateVar
     .withTransform (msg) ->
       msg.map(-> yes)


  @defineLazy 'completeEditChannel', ->
   new Transmitter.Channels.SimpleChannel()
     .fromSource @inputKeypressEvt
     .toTarget @editStateVar
     .withTransform (msg) ->
       msg.map( (e) -> keycode(e) not in ['esc', 'enter'])


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


  class ClassToggleVar extends Transmitter.Nodes.Variable
    constructor: (@$element, @class) ->
    set: (state) -> @$element.toggleClass(@class, !!state); this
    get: -> @$element.hasClass(@class)

  @defineLazy 'isCompletedClassVar', ->
    new ClassToggleVar(@$element, 'completed')

  @defineLazy 'editStateVar', ->
    new ClassToggleVar(@$element, 'editing')


class TodoListView extends Transmitter.Nodes.Record

  constructor: (@$element) ->

  init: (tr) ->
    @viewElementListChannel.connect(tr)

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
        views.mapIfMatch(
          (view) -> view.$element[0]
          (view, element) -> view.$element[0] == element
        )



class TodoViewChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@todo, @view) ->

  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .withOrigin @todo.labelVar
      .withDerived @view.labelVar

  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .withOrigin @todo.labelVar
      .withDerived @view.labelInputVar

  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .withOrigin @todo.isCompletedVar
      .withDerived @view.isCompletedInputVar

  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .withOrigin @todo.isCompletedVar
      .withDerived @view.isCompletedClassVar


todoList = new Transmitter.Nodes.List()

todoListView = new TodoListView($('.todo-list'))

todoListViewChannel = new Transmitter.Channels.ListChannel()
  .withOrigin todoList
  .withMapOrigin (todo) -> console.log todo; new TodoView(todo)
  .initOrigin()
  .withDerived todoListView.viewList
  .withMatchOriginDerived (todo, todoView) -> console.log todo, todoView; todo == todoView.todo
  .withOriginDerivedChannel (todo, todoView) ->
    new TodoViewChannel(todo, todoView)


Transmitter.setLogging off

Transmitter.startTransmission (tr) ->
  todoListView.init(tr)
  todoListViewChannel.connect(tr)

  todo1 = new Todo()
  todo2 = new Todo()
  todo1.labelVar.updateState(tr, 'Todo 1')
  todo2.labelVar.updateState(tr, 'Todo 2')
  todo2.isCompletedVar.updateState(tr, yes)
  todoList.updateState(tr, [todo1, todo2])
