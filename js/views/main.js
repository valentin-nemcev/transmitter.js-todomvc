import {inspect} from 'util';

import $ from 'jquery';

import * as Transmitter from 'transmitter/index.es';

import {
  getKeycodeMatcher,
  VisibilityToggleVar,
  ClassToggleVar,
} from '../helpers';

class EditStateChannel extends Transmitter.Channels.CompositeChannel {

  constructor(todoView) {
    this.todoView = todoView;

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSource(this.todoView.startEditEvt)
      .toTarget(this.todoView.editStateVar)
      .withTransform(
        (startEditPayload) => startEditPayload.map( () => true )
      );

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSource(this.todoView.acceptEditEvt)
      .toTarget(this.todoView.editStateVar)
      .withTransform(
        (acceptEditPayload) => acceptEditPayload.map( () => false )
      );

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSource(this.todoView.rejectEditEvt)
      .toTarget(this.todoView.editStateVar)
      .withTransform(
        (rejectEditPayload) => rejectEditPayload.map( () => false )
      );
  }
}


class TodoView {

  inspect() {
    return '[TodoView ' + inspect(this.todo.labelVar.get()) + ']';
  }

  constructor(todo) {
    this.todo = todo;
    this.$element = $('<li/>').append(
      $('<div/>', {class: 'view'})
      .append(
        this.$checkbox = $('<input/>', {class: 'toggle', type: 'checkbox'}),
        this.$label = $('<label/>'),
        this.$destroy = $('<button/>', {class: 'destroy'})
      ),
      this.$edit = $('<input/>', {class: 'edit'})
    );

    this.labelVar =
      new Transmitter.DOMElement.TextVar(this.$label[0]);

    this.labelInputVar =
      new Transmitter.DOMElement.InputValueVar(this.$edit[0]);

    this.isCompletedInputVar =
      new Transmitter.DOMElement.CheckboxStateVar(this.$checkbox[0]);

    this.labelDblclickEvt =
      new Transmitter.DOMElement.DOMEvent(this.$label[0], 'dblclick');

    this.inputKeypressEvt =
      new Transmitter.DOMElement.DOMEvent(this.$edit[0], 'keyup');

    this.destroyClickEvt =
      new Transmitter.DOMElement.DOMEvent(this.$destroy[0], 'click');

    this.isCompletedClassVar = new ClassToggleVar(this.$element, 'completed');
    this.editStateVar = new ClassToggleVar(this.$element, 'editing');

    this.startEditEvt = this.labelDblclickEvt;
    this.acceptEditEvt = new Transmitter.Nodes.RelayNode();
    this.rejectEditEvt = new Transmitter.Nodes.RelayNode();

    this.acceptEditChannel = new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource(this.inputKeypressEvt)
      .toTarget(this.acceptEditEvt)
      .withTransform(getKeycodeMatcher('enter'));

    this.rejectEditChannel = new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource(this.inputKeypressEvt)
      .toTarget(this.rejectEditEvt)
      .withTransform(getKeycodeMatcher('esc'));
  }

  init(tr) {
    this.editStateVar.init(tr, false);
    this.acceptEditChannel.init(tr);
    this.rejectEditChannel.init(tr);
    this.editStateChannel = new EditStateChannel(this).init(tr);
    return this;
  }

  createRemoveTodoChannel() {
    return new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource(this.destroyClickEvt)
      .withTransform(
        (destroyClickPayload) =>
          destroyClickPayload.map( () => this.todo ).toRemoveListElement()
      );
  }
}


class TodoViewChannel extends Transmitter.Channels.CompositeChannel {

  inspect() {
    return this.todo.inspect() + '-' + this.todoView.inspect();
  }

  constructor(todo, todoView) {
    this.todo = todo;
    this.todoView = todoView;

    this.defineVariableChannel()
      .withOrigin(this.todo.labelVar)
      .withDerived(this.todoView.labelVar);

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSources(this.todoView.labelInputVar, this.todoView.acceptEditEvt)
      .toTarget(this.todo.labelVar)
      .withTransform(
        ([labelPayload, acceptPayload]) =>
          labelPayload.replaceByNoop(acceptPayload)
      );

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSources(
        this.todo.labelVar,
        this.todoView.startEditEvt,
        this.todoView.rejectEditEvt
      )
      .toTarget(this.todoView.labelInputVar)
      .withTransform(
        ([labelPayload, startPayload, rejectPayload]) =>
          labelPayload.replaceByNoop(startPayload.replaceNoopBy(rejectPayload))
      );

    this.defineVariableChannel()
      .withOrigin(this.todo.isCompletedVar)
      .withDerived(this.todoView.isCompletedInputVar);

    this.defineVariableChannel()
      .inForwardDirection()
      .withOrigin(this.todo.isCompletedVar)
      .withDerived(this.todoView.isCompletedClassVar);
  }
}


export default class MainView {
  constructor($element) {
    this.$element = $element;

    this.viewList = new Transmitter.Nodes.List();
    this.elementList =
      new Transmitter.DOMElement.ChildrenList(
        this.$element.find('.todo-list')[0]
      );

    this.viewElementListChannel =
      new Transmitter.Channels.SimpleChannel()
        .inForwardDirection()
        .fromSource(this.viewList)
        .toTarget(this.elementList)
        .withTransform(
          (views) =>
          views.updateMatching(
            (view) => view.$element[0],
            (view, element) => view.$element[0] === element
          )
        );

    const $toggleAll = this.$element.find('.toggle-all');
    this.toggleAllCheckboxVar =
      new Transmitter.DOMElement.CheckboxStateVar($toggleAll[0]);

    this.toggleAllChangeEvt =
      new Transmitter.DOMElement.DOMEvent($toggleAll[0], 'click');

    this.isVisibleVar = new VisibilityToggleVar(this.$element);
  }

  init(tr) {
    return this.viewElementListChannel.init(tr);
  }

  createTodosChannel(todos, activeFilter) {
    return new MainViewChannel(
      todos.todoList, todos.withComplete, this, activeFilter
    );
  }
}


class ToggleAllChannel extends Transmitter.Channels.CompositeChannel {

  constructor(todoList,
              todoListWithComplete,
              toggleAllCheckboxVar,
              toggleAllChangeEvt) {
    this.todoList = todoList;
    this.todoListWithComplete = todoListWithComplete;
    this.toggleAllCheckboxVar = toggleAllCheckboxVar;
    this.toggleAllChangeEvt = toggleAllChangeEvt;

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSource(this.todoListWithComplete)
      .toTarget(this.toggleAllCheckboxVar)
      .withTransform(
        (todoListWithCompletePayload) =>
          todoListWithCompletePayload.toSetVariable().map(
            (todos) => todos.every( ([, isCompleted]) => isCompleted )
          )
      );

    this.toggleAllDynamicChannelVar =
      new Transmitter.ChannelNodes.DynamicChannelVariable(
        'targets',
        () =>
          new Transmitter.Channels.SimpleChannel()
            .inBackwardDirection()
            .fromSources(this.toggleAllCheckboxVar, this.toggleAllChangeEvt)
            .withTransform(
              ([isCompletedPayload, changePayload],
               isCompletedListPayload) => {
                const payload = isCompletedPayload
                  .replaceByNoop(changePayload)
                  .map( (state) => !state );
                return isCompletedListPayload.map( () => payload );
              }
            )
      );

    this.defineSimpleChannel()
      .fromSource(this.todoList)
      .toConnectionTarget(this.toggleAllDynamicChannelVar)
      .withTransform(
        (todoListPayload) => {
          if (todoListPayload == null) return null;
          return todoListPayload.map( ({isCompletedVar}) => isCompletedVar );
        }
      );
  }
}


class MainViewChannel extends Transmitter.Channels.CompositeChannel {

  inspect() {
    return this.todoList.inspect() + '-' + this.todoListView.inspect();
  }

  constructor(todoList, todoListWithComplete, todoListView, activeFilter) {
    this.todoList = todoList;
    this.todoListWithComplete = todoListWithComplete;
    this.todoListView = todoListView;
    this.activeFilter = activeFilter;

    this.removeTodoChannelList = new Transmitter.ChannelNodes.ChannelList();
    this.filteredTodoList = new Transmitter.Nodes.List();

    this.defineSimpleChannel()
      .fromSource(this.todoListView.viewList)
      .toConnectionTarget(this.removeTodoChannelList)
      .withTransform(
        (todoViews) =>
          todoViews != null
            ? todoViews.map(
              (todoView) =>
                todoView.createRemoveTodoChannel().toTarget(this.todoList)
            )
            : null
      );

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSources(this.todoListWithComplete, this.activeFilter)
      .toTarget(this.filteredTodoList)
      .withTransform(
        ([todoListPayload, activeFilterPayload]) => {
          const filter = activeFilterPayload.get();
          return todoListPayload
            .filter(
              ([, isCompleted]) => {
                switch (filter) {
                case 'active':
                  return !isCompleted;
                case 'completed':
                  return isCompleted;
                default:
                  return true;
                }
              }
            )
            .map( ([todo]) => todo );
        }
      );

    this.defineListChannel()
      .inForwardDirection()
      .withOrigin(this.filteredTodoList)
      .withMapOrigin(
        (todo, tr) => new TodoView(todo).init(tr)
      )
      .withDerived(this.todoListView.viewList)
      .withMatchOriginDerived(
        (todo, todoView) => todo === todoView.todo
      )
      .withMatchOriginDerivedChannel(
        (todo, todoView, channel) =>
          channel.todo === todo && channel.todoView === todoView
      )
      .withOriginDerivedChannel(
        (todo, todoView) => new TodoViewChannel(todo, todoView)
      );

    this.addChannel(
      new ToggleAllChannel(
        this.todoList,
        this.todoListWithComplete,
        this.todoListView.toggleAllCheckboxVar,
        this.todoListView.toggleAllChangeEvt
      )
    );

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSource(this.todoList)
      .toTarget(this.todoListView.isVisibleVar)
      .withTransform(
        (todoListPayload) =>
          todoListPayload.toSetVariable().map( (todos) => todos.length > 0 )
      );
  }
}
