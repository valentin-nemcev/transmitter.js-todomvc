'use strict'

$ = require 'jquery'
keycode = require 'keycode'

Transmitter = require 'transmitter'


class Todo extends Transmitter.Nodes.Record

  @defineVar 'labelVar'

  @defineVar 'isCompletedVar'


class TodoView extends Transmitter.Nodes.Record

  constructor: ->
    @$element = $('<li/>').append(
      $('<div/>', class: 'view').append(
        $('<input/>', class: 'toggle', type: 'checkbox')
        $('<label/>')
        $('<button/>', class: 'destroy')
      )
      $('<input/>', class: 'edit')
    )


  init: (sender) ->
    sender.updateNodeState(@editStateVar, off)
    sender.connect(@startEditChannel)
    sender.connect(@completeEditChannel)
    return this


  @defineLazy 'startEditChannel', ->
   Transmitter.connection()
     .fromSource @labelDblclickEvt
     .toTarget @editStateVar
     .withTransform (msg) ->
       msg.mapValue(-> yes).toState()


  @defineLazy 'completeEditChannel', ->
   Transmitter.connection()
     .fromSource @inputKeypressEvt
     .toTarget @editStateVar
     .withTransform (msg) ->
       msg.mapValue( (e) -> keycode(e) not in ['esc', 'enter']).toState()


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


  class ClassToggleVar extends Transmitter.Nodes.StatefulNode
    constructor: (@$element, @class) ->
    setValue: (state) -> @$element.toggleClass(@class, !!state); this
    getValue: -> @$element.hasClass(@class)

  @defineLazy 'isCompletedClassVar', ->
    new ClassToggleVar(@$element, 'completed')

  @defineLazy 'editStateVar', ->
    new ClassToggleVar(@$element, 'editing')


class TodoViewChannel extends Transmitter.Channels.RecordChannel

  constructor: (@todo, @view) ->

  @defineChannel (channel) ->
    channel
      .withOrigin @todo.labelVar
      .withDerived @view.labelVar

  @defineChannel (channel) ->
    channel
      .withOrigin @todo.labelVar
      .withDerived @view.labelInputVar

  @defineChannel (channel) ->
    channel
      .withOrigin @todo.isCompletedVar
      .withDerived @view.isCompletedInputVar

  @defineChannel (channel) ->
    channel
      .withOrigin @todo.isCompletedVar
      .withDerived @view.isCompletedClassVar



todo1 = new Todo()
todo2 = new Todo()

todoView1 = new TodoView()
todoView2 = new TodoView()


todoViewChannel1 = new TodoViewChannel(todo1, todoView1)
todoViewChannel2 = new TodoViewChannel(todo2, todoView2)

Transmitter.startTransmission (sender) ->
  todoView1.init(sender)
  todoView2.init(sender)
  sender.connect(todoViewChannel1)
  sender.connect(todoViewChannel2)


todoView1.$element.appendTo('.todo-list')
todoView2.$element.appendTo('.todo-list')

Transmitter.updateNodeState(todo1.labelVar, 'Todo 1')
Transmitter.updateNodeState(todo2.labelVar, 'Todo 2')
Transmitter.updateNodeState(todo2.isCompletedVar, yes)
