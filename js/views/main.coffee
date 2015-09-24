'use strict'


{inspect} = require 'util'
$ = require 'jquery'

Transmitter = require 'transmitter'

{getKeycodeMatcher, VisibilityToggleVar, ClassToggleVar} = require '../helpers'


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
      .withTransform getKeycodeMatcher('enter')


  @defineLazy 'rejectEditChannel', ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @inputKeypressEvt
      .toTarget @rejectEditEvt
      .withTransform getKeycodeMatcher('esc')


  class EditStateChannel extends Transmitter.Channels.CompositeChannel

    constructor: (@todoView) ->

    @defineChannel ->
      new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSource @todoView.startEditEvt
        .toTarget @todoView.editStateVar
        .withTransform (startEditPayload) ->
          startEditPayload.map -> yes

    @defineChannel ->
      new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSource @todoView.acceptEditEvt
        .toTarget @todoView.editStateVar
        .withTransform (acceptEditPayload) ->
          acceptEditPayload.map -> no

    @defineChannel ->
      new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSource @todoView.rejectEditEvt
        .toTarget @todoView.editStateVar
        .withTransform (rejectEditPayload) ->
          rejectEditPayload.map -> no


  createRemoveTodoChannel: ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @destroyClickEvt
      .withTransform (destroyClickPayload) =>
        destroyClickPayload.map(=> @todo).toRemoveListElement()


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

  @defineLazy 'isCompletedClassVar', ->
    new ClassToggleVar(@$element, 'completed')

  @defineLazy 'editStateVar', ->
    new ClassToggleVar(@$element, 'editing')



class TodoViewChannel extends Transmitter.Channels.CompositeChannel

  inspect: ->
    @todo.inspect() + '-' + @todoView.inspect()


  constructor: (@todo, @todoView) ->


  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .withOrigin @todo.labelVar
      .withDerived @todoView.labelVar


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSources @todoView.labelInputVar, @todoView.acceptEditEvt
      .toTarget @todo.labelVar
      .withTransform ([labelPayload, acceptPayload]) =>
        labelPayload.replaceByNoop(acceptPayload)


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSources(
        @todo.labelVar, @todoView.startEditEvt, @todoView.rejectEditEvt)
      .toTarget @todoView.labelInputVar
      .withTransform ([labelPayload, startPayload, rejectPayload]) =>
        labelPayload.replaceByNoop(startPayload.replaceNoopBy(rejectPayload))


  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .withOrigin @todo.isCompletedVar
      .withDerived @todoView.isCompletedInputVar


  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .inForwardDirection()
      .withOrigin @todo.isCompletedVar
      .withDerived @todoView.isCompletedClassVar



module.exports = class MainView extends Transmitter.Nodes.Record

  constructor: (@$element) ->

  init: (tr) ->
    @viewElementListChannel.init(tr)

  @defineLazy 'viewList', ->
    new Transmitter.Nodes.List()

  @defineLazy 'elementList', ->
    new Transmitter.DOMElement.ChildrenList(@$element.find('.todo-list')[0])

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

  @defineLazy 'toggleAllCheckboxVar', ->
    new Transmitter.DOMElement.CheckboxStateVar(@$element.find('.toggle-all')[0])

  @defineLazy 'toggleAllChangeEvt', ->
    new Transmitter.DOMElement.DOMEvent(@$element.find('.toggle-all')[0], 'click')

  @defineLazy 'isVisibleVar', ->
    new VisibilityToggleVar(@$element)

  createTodosChannel: (todos, activeFilter) ->
    new MainViewChannel(todos.todoList, todos.withComplete, this, activeFilter)



class ToggleAllChannel extends Transmitter.Channels.CompositeChannel

  constructor:
    (@todoList, @todoListWithComplete, @toggleAllCheckboxVar, @toggleAllChangeEvt) ->

  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todoListWithComplete
      .toTarget @toggleAllCheckboxVar
      .withTransform (todoListWithComplete) ->
        todoListWithComplete.toSetVariable().map (todos) ->
          todos.every ([todo, isCompleted]) -> isCompleted


  @defineLazy 'toggleAllChannelVar', ->
    new Transmitter.ChannelNodes.ChannelVariable()


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .fromSource @todoList
      .toConnectionTarget @toggleAllChannelVar
      .withTransform (todoListPayload) =>
        return null unless todoListPayload?
        todoListPayload
          .map ({isCompletedVar}) -> isCompletedVar
          .toSetVariable()
          .map (isCompletedVars) =>
            @createToggleAllChannel(isCompletedVars).inBackwardDirection()


  createToggleAllChannel: (isCompletedVars) ->
    new Transmitter.Channels.SimpleChannel()
      .fromSources @toggleAllCheckboxVar, @toggleAllChangeEvt
      .toDynamicTargets isCompletedVars
      .withTransform ([isCompletedPayload, changePayload]) =>
        payload = isCompletedPayload
          .replaceByNoop(changePayload).map (state) -> !state
        isCompletedVars.map -> payload



class MainViewChannel extends Transmitter.Channels.CompositeChannel

  inspect: ->
    @todoList.inspect() + '-' + @todoListView.inspect()


  constructor: (@todoList, @todoListWithComplete, @todoListView, @activeFilter) ->


  @defineLazy 'removeTodoChannelList', ->
    new Transmitter.ChannelNodes.ChannelList()


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .fromSource @todoListView.viewList
      .toConnectionTarget @removeTodoChannelList
      .withTransform (todoViews) =>
        todoViews?.map (todoView) =>
          todoView.createRemoveTodoChannel()
            .toTarget(@todoList)


  @defineLazy 'filteredTodoList', ->
    new Transmitter.Nodes.List()


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSources @todoListWithComplete, @activeFilter
      .toTarget @filteredTodoList
      .withTransform ([todoListPayload, activeFilterPayload]) =>
        filter = activeFilterPayload.get()
        todoListPayload
          .filter ([todo, isCompleted]) ->
            switch filter
              when 'active'    then !isCompleted
              when 'completed' then isCompleted
              else true
          .map ([todo]) -> todo


  @defineChannel ->
    new Transmitter.Channels.ListChannel()
    .inForwardDirection()
    .withOrigin @filteredTodoList
    .withMapOrigin (todo, tr) -> new TodoView(todo).init(tr)
    .withDerived @todoListView.viewList
    .withMatchOriginDerived (todo, todoView) -> todo == todoView.todo
    .withMatchOriginDerivedChannel (todo, todoView, channel) ->
      channel.todo == todo and channel.todoView == todoView
    .withOriginDerivedChannel (todo, todoView) ->
      new TodoViewChannel(todo, todoView)


  @defineChannel ->
    new ToggleAllChannel(@todoList, @todoListWithComplete,
      @todoListView.toggleAllCheckboxVar, @todoListView.toggleAllChangeEvt)


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todoList
      .toTarget @todoListView.isVisibleVar
      .withTransform (todoListPayload) ->
        todoListPayload.toSetVariable().map (todos) -> todos.length > 0
