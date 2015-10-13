'use strict'


{inspect} = require 'util'
$ = require 'jquery'

Transmitter = require 'transmitter'

{getKeycodeMatcher, VisibilityToggleVar, ClassToggleVar} = require '../helpers'


class EditStateChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@todoView) ->
    @addChannel(
      new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSource @todoView.startEditEvt
        .toTarget @todoView.editStateVar
        .withTransform (startEditPayload) ->
          startEditPayload.map -> yes
    )

    @addChannel(
      new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSource @todoView.acceptEditEvt
        .toTarget @todoView.editStateVar
        .withTransform (acceptEditPayload) ->
          acceptEditPayload.map -> no
    )

    @addChannel(
      new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSource @todoView.rejectEditEvt
        .toTarget @todoView.editStateVar
        .withTransform (rejectEditPayload) ->
          rejectEditPayload.map -> no
    )


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

    @labelVar =
      new Transmitter.DOMElement.TextVar(@$element.find('label')[0])

    @labelInputVar =
      new Transmitter.DOMElement.InputValueVar(@$element.find('.edit')[0])

    checkbox = @$element.find('.toggle')[0]
    @isCompletedInputVar =
      new Transmitter.DOMElement.CheckboxStateVar(checkbox)

    @labelDblclickEvt =
      new Transmitter.DOMElement.DOMEvent(@$element.find('label')[0], 'dblclick')

    @inputKeypressEvt =
      new Transmitter.DOMElement.DOMEvent(@$element.find('.edit')[0], 'keyup')

    @destroyClickEvt =
      new Transmitter.DOMElement.DOMEvent(@$element.find('.destroy')[0], 'click')

    @isCompletedClassVar =
      new ClassToggleVar(@$element, 'completed')

    @editStateVar =
      new ClassToggleVar(@$element, 'editing')

    @startEditEvt = @labelDblclickEvt
    @acceptEditEvt = new Transmitter.Nodes.RelayNode()
    @rejectEditEvt = new Transmitter.Nodes.RelayNode()


    @acceptEditChannel =
      new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSource @inputKeypressEvt
        .toTarget @acceptEditEvt
        .withTransform getKeycodeMatcher('enter')


    @rejectEditChannel =
      new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSource @inputKeypressEvt
        .toTarget @rejectEditEvt
        .withTransform getKeycodeMatcher('esc')


  init: (tr) ->
    @editStateVar.init(tr, off)
    @acceptEditChannel.init(tr)
    @rejectEditChannel.init(tr)
    @editStateChannel = new EditStateChannel(this).init(tr)
    return this


  createRemoveTodoChannel: ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @destroyClickEvt
      .withTransform (destroyClickPayload) =>
        destroyClickPayload.map(=> @todo).toRemoveListElement()



class TodoViewChannel extends Transmitter.Channels.CompositeChannel

  inspect: ->
    @todo.inspect() + '-' + @todoView.inspect()


  constructor: (@todo, @todoView) ->
    @addChannel(
      new Transmitter.Channels.VariableChannel()
        .withOrigin @todo.labelVar
        .withDerived @todoView.labelVar
    )

    @addChannel(
      new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSources @todoView.labelInputVar, @todoView.acceptEditEvt
        .toTarget @todo.labelVar
        .withTransform ([labelPayload, acceptPayload]) =>
          labelPayload.replaceByNoop(acceptPayload)
    )

    @addChannel(
      new Transmitter.Channels.SimpleChannel()
        .inForwardDirection()
        .fromSources(
          @todo.labelVar, @todoView.startEditEvt, @todoView.rejectEditEvt)
        .toTarget @todoView.labelInputVar
        .withTransform ([labelPayload, startPayload, rejectPayload]) =>
          labelPayload.replaceByNoop(startPayload.replaceNoopBy(rejectPayload))
    )

    @addChannel(
      new Transmitter.Channels.VariableChannel()
        .withOrigin @todo.isCompletedVar
        .withDerived @todoView.isCompletedInputVar
    )

    @addChannel(
      new Transmitter.Channels.VariableChannel()
        .inForwardDirection()
        .withOrigin @todo.isCompletedVar
        .withDerived @todoView.isCompletedClassVar
    )



module.exports = class MainView extends Transmitter.Nodes.Record

  constructor: (@$element) ->

    @viewList = new Transmitter.Nodes.List()
    @elementList =
      new Transmitter.DOMElement.ChildrenList(@$element.find('.todo-list')[0])

    @viewElementListChannel =
      new Transmitter.Channels.SimpleChannel()
        .inForwardDirection()
        .fromSource @viewList
        .toTarget @elementList
        .withTransform (views) ->
          views.updateMatching(
            (view) -> view.$element[0]
            (view, element) -> view.$element[0] == element
          )

    @toggleAllCheckboxVar =
      new Transmitter.DOMElement.CheckboxStateVar(@$element.find('.toggle-all')[0])

    @toggleAllChangeEvt =
      new Transmitter.DOMElement.DOMEvent(@$element.find('.toggle-all')[0], 'click')

    @isVisibleVar =
      new VisibilityToggleVar(@$element)


  init: (tr) ->
    @viewElementListChannel.init(tr)


  createTodosChannel: (todos, activeFilter) ->
    new MainViewChannel(todos.todoList, todos.withComplete, this, activeFilter)



class ToggleAllChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@todoList, @todoListWithComplete, @toggleAllCheckboxVar, @toggleAllChangeEvt) ->
    @addChannel(
      new Transmitter.Channels.SimpleChannel()
        .inForwardDirection()
        .fromSource @todoListWithComplete
        .toTarget @toggleAllCheckboxVar
        .withTransform (todoListWithComplete) ->
          todoListWithComplete.toSetVariable().map (todos) ->
            todos.every ([todo, isCompleted]) -> isCompleted
    )

    @toggleAllDynamicChannelVar =
      new Transmitter.ChannelNodes.DynamicChannelVariable('targets', =>
        new Transmitter.Channels.SimpleChannel()
          .inBackwardDirection()
          .fromSources @toggleAllCheckboxVar, @toggleAllChangeEvt
          .withTransform \
            ([isCompletedPayload, changePayload], isCompletedListPayload) =>
              payload = isCompletedPayload
                .replaceByNoop(changePayload).map (state) -> !state
              isCompletedListPayload.map(-> payload)
      )

    @addChannel(
      new Transmitter.Channels.SimpleChannel()
        .fromSource @todoList
        .toConnectionTarget @toggleAllDynamicChannelVar
        .withTransform (todoListPayload) =>
          return null unless todoListPayload?
          todoListPayload
            .map ({isCompletedVar}) -> isCompletedVar
    )



class MainViewChannel extends Transmitter.Channels.CompositeChannel

  inspect: ->
    @todoList.inspect() + '-' + @todoListView.inspect()


  constructor: (@todoList, @todoListWithComplete, @todoListView, @activeFilter) ->
    @removeTodoChannelList = new Transmitter.ChannelNodes.ChannelList()
    @filteredTodoList = new Transmitter.Nodes.List()


    @addChannel(
      new Transmitter.Channels.SimpleChannel()
        .fromSource @todoListView.viewList
        .toConnectionTarget @removeTodoChannelList
        .withTransform (todoViews) =>
          todoViews?.map (todoView) =>
            todoView.createRemoveTodoChannel()
              .toTarget(@todoList)
    )

    @addChannel(
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
    )

    @addChannel(
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
    )

    @addChannel(
      new ToggleAllChannel(@todoList, @todoListWithComplete,
        @todoListView.toggleAllCheckboxVar, @todoListView.toggleAllChangeEvt)
    )

    @addChannel(
      new Transmitter.Channels.SimpleChannel()
        .inForwardDirection()
        .fromSource @todoList
        .toTarget @todoListView.isVisibleVar
        .withTransform (todoListPayload) ->
          todoListPayload.toSetVariable().map (todos) -> todos.length > 0
    )
