import {inspect} from 'util';

import $ from 'jquery';

import * as Transmitter from 'transmitter-framework/index.es';

import {
  getKeycodeMatcher,
  VisibilityToggleValue,
  ClassToggleValue,
} from '../helpers';

class EditStateChannel extends Transmitter.Channels.CompositeChannel {

  constructor(todoView) {
    super();
    this.todoView = todoView;

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSource(this.todoView.startEditEvt)
      .toTarget(this.todoView.editStateValue)
      .withTransform(
        (startEditPayload) => startEditPayload.map( () => true )
      );

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSource(this.todoView.acceptEditEvt)
      .toTarget(this.todoView.editStateValue)
      .withTransform(
        (acceptEditPayload) => acceptEditPayload.map( () => false )
      );

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSource(this.todoView.rejectEditEvt)
      .toTarget(this.todoView.editStateValue)
      .withTransform(
        (rejectEditPayload) => rejectEditPayload.map( () => false )
      );
  }
}


class TodoView {

  inspect() {
    return '[TodoView ' + inspect(this.todo.labelValue.get()) + ']';
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

    this.labelValue =
      new Transmitter.DOMElement.TextValue(this.$label[0]);

    this.labelInputValue =
      new Transmitter.DOMElement.InputValue(this.$edit[0]);

    this.isCompletedInputValue =
      new Transmitter.DOMElement.CheckboxStateValue(this.$checkbox[0]);

    this.labelDblclickEvt =
      new Transmitter.DOMElement.DOMEvent(this.$label[0], 'dblclick');

    this.inputKeypressEvt =
      new Transmitter.DOMElement.DOMEvent(this.$edit[0], 'keyup');

    this.destroyClickEvt =
      new Transmitter.DOMElement.DOMEvent(this.$destroy[0], 'click');

    this.isCompletedClassValue =
      new ClassToggleValue(this.$element, 'completed');
    this.editStateValue = new ClassToggleValue(this.$element, 'editing');

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
    this.editStateValue.set(false).init(tr);
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
          destroyClickPayload.map( () => this.todo ).toRemoveAction()
      );
  }
}


class TodoViewChannel extends Transmitter.Channels.CompositeChannel {

  inspect() {
    return this.todo.inspect() + '-' + this.todoView.inspect();
  }

  constructor(todo, todoView) {
    super();
    this.todo = todo;
    this.todoView = todoView;

    this.defineBidirectionalChannel()
      .withOriginDerived(this.todo.labelValue, this.todoView.labelValue);

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSources(this.todoView.labelInputValue, this.todoView.acceptEditEvt)
      .toTarget(this.todo.labelValue)
      .withTransform(
        ([labelPayload, acceptPayload]) =>
          labelPayload.replaceByNoOp(acceptPayload)
      );

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSources(
        this.todo.labelValue,
        this.todoView.startEditEvt,
        this.todoView.rejectEditEvt
      )
      .toTarget(this.todoView.labelInputValue)
      .withTransform(
        ([labelPayload, startPayload, rejectPayload]) =>
          labelPayload.replaceByNoOp(startPayload.replaceNoOpBy(rejectPayload))
      );

    this.defineBidirectionalChannel()
      .withOriginDerived(
        this.todo.isCompletedValue,
        this.todoView.isCompletedInputValue
      );

    this.defineBidirectionalChannel()
      .inForwardDirection()
      .withOriginDerived(
        this.todo.isCompletedValue,
        this.todoView.isCompletedClassValue
      );
  }
}


export default class MainView {
  constructor($element) {
    this.$element = $element;

    this.viewMap = new Transmitter.Nodes.OrderedMapNode();
    this.elementList =
      new Transmitter.DOMElement.ChildrenList(
        this.$element.find('.todo-list')[0]
      );

    this.viewElementListChannel =
      new Transmitter.Channels.SimpleChannel()
        .inForwardDirection()
        .fromSource(this.viewMap)
        .toTarget(this.elementList)
        .withTransform(
          (views) => views.map( (view) => view.$element[0] )
        );

    const $toggleAll = this.$element.find('.toggle-all');
    this.toggleAllCheckboxValue =
      new Transmitter.DOMElement.CheckboxStateValue($toggleAll[0]);

    this.toggleAllChangeEvt =
      new Transmitter.DOMElement.DOMEvent($toggleAll[0], 'click');

    this.isVisibleValue = new VisibilityToggleValue(this.$element);
  }

  init(tr) {
    return this.viewElementListChannel.init(tr);
  }

  createTodosChannel(todos, activeFilter) {
    return new MainViewChannel(
      todos.todoSet, todos.withComplete, this, activeFilter
    );
  }
}


class ToggleAllChannel extends Transmitter.Channels.CompositeChannel {

  constructor(
    todoSet,
    todoListWithComplete,
    toggleAllCheckboxValue,
    toggleAllChangeEvt
  ) {
    super();
    this.todoSet = todoSet;
    this.todoListWithComplete = todoListWithComplete;
    this.toggleAllCheckboxValue = toggleAllCheckboxValue;
    this.toggleAllChangeEvt = toggleAllChangeEvt;

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSource(this.todoListWithComplete)
      .toTarget(this.toggleAllCheckboxValue)
      .withTransform(
        (todoListWithCompletePayload) =>
          todoListWithCompletePayload.joinValues().map(
            (todos) => todos.every( ([, isCompleted]) => isCompleted )
          )
      );

    this.toggleAllDynamicChannelValue =
      new Transmitter.ChannelNodes.DynamicListChannelValue(
        'targets',
        (targets) =>
          new Transmitter.Channels.SimpleChannel()
            .inBackwardDirection()
            .fromSources(this.toggleAllCheckboxValue, this.toggleAllChangeEvt)
            .toDynamicTargets(targets)
            .withTransform(
              ([isCompletedPayload, changePayload],
               isCompletedListPayload) => {
                const payload = isCompletedPayload
                  .replaceByNoOp(changePayload)
                  .map( (state) => !state );
                return isCompletedListPayload.map( () => payload );
              }
            )
      );

    this.defineNestedSimpleChannel()
      .fromSource(this.todoSet)
      .toChannelTarget(this.toggleAllDynamicChannelValue)
      .withTransform(
        (todoListPayload) => {
          if (todoListPayload == null) return null;
          return todoListPayload
            .map( ({isCompletedValue}) => isCompletedValue );
        }
      );
  }
}


class MainViewChannel extends Transmitter.Channels.CompositeChannel {

  inspect() {
    return this.todoSet.inspect() + '-' + this.todoListView.inspect();
  }

  constructor(todoSet, todoListWithComplete, todoListView, activeFilter) {
    super();
    this.todoSet = todoSet;
    this.todoListWithComplete = todoListWithComplete;
    this.todoListView = todoListView;
    this.activeFilter = activeFilter;

    this.removeTodoChannelList = new Transmitter.ChannelNodes.ChannelList();
    this.filteredTodoList = new Transmitter.Nodes.ListNode();

    this.defineNestedSimpleChannel()
      .fromSource(this.todoListView.viewMap)
      .toChannelTarget(this.removeTodoChannelList)
      .withTransform(
        (todoViews) =>
          todoViews != null
            ? todoViews.map(
              (todoView) =>
                todoView.createRemoveTodoChannel().toTarget(this.todoSet)
            )
            : null
      );

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSources(this.todoListWithComplete, this.activeFilter)
      .toTarget(this.filteredTodoList)
      .withTransform(
        ([todoListPayload, activeFilterPayload]) => {
          const {value: entry} =
            activeFilterPayload[Symbol.iterator]().next();
          const filter = entry[1];
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

    this.defineNestedBidirectionalChannel()
      .inForwardDirection()
      .withOriginDerived(this.filteredTodoList, this.todoListView.viewMap)
      // .useMapUpdate()
      .withMapOrigin(
        (todo, tr) => new TodoView(todo).init(tr)
      )
      .withOriginDerivedChannel(
        (todo, todoView) => new TodoViewChannel(todo, todoView)
      );

    this.addChannel(
      new ToggleAllChannel(
        this.todoSet,
        this.todoListWithComplete,
        this.todoListView.toggleAllCheckboxValue,
        this.todoListView.toggleAllChangeEvt
      )
    );

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSource(this.todoSet)
      .toTarget(this.todoListView.isVisibleValue)
      .withTransform(
        (todoListPayload) =>
          todoListPayload.joinValues().map( (todos) => todos.length > 0 )
      );
  }
}
