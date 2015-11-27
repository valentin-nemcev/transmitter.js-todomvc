import * as Transmitter from 'transmitter';

import {VisibilityToggleVar} from '../helpers';

class ActiveFilterSelector extends Transmitter.Nodes.Variable {
  constructor($filters) {
    this.$filters = $filters;
  }

  get() {
    return (this.$filters.find('a.selected').attr('href') || '')
      .match(/\w*$/)[0] || 'all';
  }

  set(filter) {
    const href = filter === 'all' ? '' : filter;
    this.$filters
      .find('a').removeClass('selected')
      .filter(`[href='#/${href}']`).addClass('selected');
    return this;
  }
}

export default class FooterView {
  constructor($element) {
    this.$element = $element;
    this.$clearCompleted = this.$element.find('.clear-completed');

    this.completeCountVar =
      new Transmitter.DOMElement.TextVar(this.$element.find('.todo-count')[0]);

    this.clearCompletedIsVisibleVar =
      new VisibilityToggleVar(this.$clearCompleted);

    this.clearCompletedClickEvt =
      new Transmitter.DOMElement.DOMEvent(this.$clearCompleted[0], 'click');

    this.isVisibleVar = new VisibilityToggleVar(this.$element);

    const $filters = this.$element.find('.filters');
    this.activeFilter = new ActiveFilterSelector($filters);
  }

  init() {}

  createTodosChannel(todos, activeFilter) {
    return new FooterViewChannel(
      todos.todoList, todos.withComplete, this, activeFilter
    );
  }
}


class FooterViewChannel extends Transmitter.Channels.CompositeChannel {
  constructor(
    todoList,
    todoListWithComplete,
    todoListFooterView,
    activeFilter
  ) {
    this.todoList = todoList;
    this.todoListWithComplete = todoListWithComplete;
    this.todoListFooterView = todoListFooterView;
    this.activeFilter = activeFilter;

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSource(this.activeFilter)
      .toTarget(this.todoListFooterView.activeFilter);

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSource(this.todoListWithComplete)
      .toTarget(this.todoListFooterView.completeCountVar)
      .withTransform(
        (todoListWithCompletePayload) =>
          todoListWithCompletePayload
            .filter( ([, isCompleted]) => !isCompleted )
            .toSetVariable()
            .map(
              ({length}) => [length, length === 1 ? 'item' : 'items'].join(' ')
            )
      );

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSource(this.todoListWithComplete)
      .toTarget(this.todoListFooterView.clearCompletedIsVisibleVar)
      .withTransform(
        (todoListWithCompletePayload) =>
          todoListWithCompletePayload
            .filter( ([, isCompleted]) => isCompleted )
            .toSetVariable()
            .map( ({length}) => length > 0 )
      );

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSources(
        this.todoListFooterView.clearCompletedClickEvt,
        this.todoListWithComplete
      )
      .toTarget(this.todoList)
      .withTransform(
        ([clearCompletedPayload, todoListWithCompletePayload]) =>
          todoListWithCompletePayload
            .replaceByNoop(clearCompletedPayload)
            .filter( ([, isCompleted]) => !isCompleted )
            .map( ([todo]) => todo )
      );

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSource(this.todoList)
      .toTarget(this.todoListFooterView.isVisibleVar)
      .withTransform(
        (todoListPayload) =>
          todoListPayload.toSetVariable().map( ({length}) => length > 0 )
      );
  }
}
