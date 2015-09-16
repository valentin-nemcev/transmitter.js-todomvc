'use strict'


keycode = require 'keycode'
$ = require 'jquery'

Transmitter = require 'transmitter'

{VisibilityToggleVar, ClassToggleVar} = require './helpers'


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



class exports.TodoListView extends Transmitter.Nodes.Record

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



class exports.TodoListViewChannel extends Transmitter.Channels.CompositeChannel

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
      .fromSource @todoListWithComplete
      .fromSource @activeFilter
      .toTarget @filteredTodoList
      .withTransform (payloads) =>
        todoListPayload = payloads.get(@todoListWithComplete)
        activeFilterPayload = payloads.get(@activeFilter)
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



class exports.NewTodoView extends Transmitter.Nodes.Record

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



class exports.TodoListFooterView extends Transmitter.Nodes.Record

  constructor: (@$element) ->


  @defineLazy 'completeCountVar', ->
    new Transmitter.DOMElement.TextVar(@$element.find('.todo-count')[0])


  @defineLazy 'clearCompletedIsVisibleVar', ->
    new VisibilityToggleVar(@$element.find('.clear-completed'))


  @defineLazy 'clearCompletedClickEvt', ->
    new Transmitter.DOMElement
      .DOMEvent(@$element.find('.clear-completed')[0], 'click')


  @defineLazy 'isVisibleVar', ->
    new VisibilityToggleVar(@$element)

  @defineLazy 'activeFilter', ->
    $filters = @$element.find('.filters')
    new class ActiveFilterSelector extends Transmitter.Nodes.Variable
      get: ->
        ($filters.find('a.selected').attr('href') ? '')
          .match(/\w*$/)[0] || 'all'
      set: (filter) ->
        filter = '' if filter is 'all'
        $filters.find('a').removeClass('selected')
          .filter("[href='#/#{filter}']").addClass('selected')



class exports.TodoListFooterViewChannel extends Transmitter.Channels.CompositeChannel

  constructor:
    (@todoList, @todoListWithComplete, @todoListFooterView, @activeFilter) ->


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @activeFilter
      .toTarget @todoListFooterView.activeFilter


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todoListWithComplete
      .toTarget @todoListFooterView.completeCountVar
      .withTransform (todoListWithComplete) ->
        Transmitter.Payloads.Variable.setLazy(->
          count = todoListWithComplete.get()
            .filter(([todo, isCompleted]) -> !isCompleted)
            .length
          items = if count is 1 then 'item' else 'items'
          "#{count} #{items} left"
        )


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todoListWithComplete
      .toTarget @todoListFooterView.clearCompletedIsVisibleVar
      .withTransform (todoListWithComplete) ->
        Transmitter.Payloads.Variable.setLazy(->
          count = todoListWithComplete.get()
            .filter(([todo, isCompleted]) -> isCompleted)
            .length
          count > 0
        )


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @todoListFooterView.clearCompletedClickEvt
      .fromSource @todoListWithComplete
      .toTarget @todoList
      .withTransform (payloads) =>
        clearCompleted = payloads.get(@todoListFooterView.clearCompletedClickEvt)
        todoListWithComplete = payloads.get(@todoListWithComplete)
        if clearCompleted.get?
          todoListWithComplete
            .filter ([todo, isCompleted]) -> !isCompleted
            .map ([todo]) -> todo
        else
          clearCompleted


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todoList
      .toTarget @todoListFooterView.isVisibleVar
      .withTransform (payload) ->
        Transmitter.Payloads.Variable.setLazy ->
          payload.get().length > 0




class exports.ToggleAllChannel extends Transmitter.Channels.CompositeChannel

  constructor:
    (@todoList, @todoListWithComplete, @toggleAllCheckboxVar, @toggleAllChangeEvt) ->

  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todoListWithComplete
      .toTarget @toggleAllCheckboxVar
      .withTransform (todoListWithComplete) ->
        Transmitter.Payloads.Variable.setLazy( ->
          todoListWithComplete.get().every ([todo, isCompleted]) -> isCompleted
        )


  @defineLazy 'toggleAllChannelVar', ->
    new Transmitter.ChannelNodes.ChannelVariable()


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .fromSource @todoList
      .toConnectionTarget @toggleAllChannelVar
      .withTransform (todoList) =>
        return null unless todoList?
        Transmitter.Payloads.Variable.setLazy =>
          @createToggleAllChannel()
            .inBackwardDirection()
            .toTargets todoList.map(({isCompletedVar}) -> isCompletedVar).get()


  createToggleAllChannel: ->
    new Transmitter.Channels.SimpleChannel()
      .fromSource @toggleAllCheckboxVar
      .fromSource @toggleAllChangeEvt
      .withTransform (payloads, isCompleted) =>
        isCompletedState = payloads.get(@toggleAllCheckboxVar)
        changed = payloads.get(@toggleAllChangeEvt)
        payload = if changed.get?
          isCompletedState.map((state) -> !state)
        else
          changed

        for key in isCompleted.keys()
          isCompleted.set(key, payload)
