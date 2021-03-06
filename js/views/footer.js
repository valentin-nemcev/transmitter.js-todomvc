import * as Transmitter from 'transmitter-framework/index.es';

import {VisibilityToggleValue} from '../helpers';

class ActiveFilterSelector extends Transmitter.Nodes.ValueNode {
  constructor($filters) {
    super();
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

    this.completeCountValue =
      new Transmitter.DOMElement.TextValue(
        this.$element.find('.todo-count')[0]
      );

    this.clearCompletedIsVisibleValue =
      new VisibilityToggleValue(this.$clearCompleted);

    this.clearCompletedClickEvt =
      new Transmitter.DOMElement.DOMEvent(this.$clearCompleted[0], 'click');

    this.isVisibleValue = new VisibilityToggleValue(this.$element);

    const $filters = this.$element.find('.filters');
    this.activeFilter = new ActiveFilterSelector($filters);
  }

  init() {}

  createTodosChannel(todos, activeFilter) {
    return new FooterViewChannel(
      todos.todoSet, todos.withComplete, this, activeFilter
    );
  }
}


class FooterViewChannel extends Transmitter.Channels.CompositeChannel {
  constructor(
    todoSet,
    todoListWithComplete,
    todoListFooterView,
    activeFilter
  ) {
    super();
    this.todoSet = todoSet;
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
      .toTarget(this.todoListFooterView.completeCountValue)
      .withTransform(
        (todoListWithCompletePayload) =>
          todoListWithCompletePayload
            .filter( ([, isCompleted]) => !isCompleted )
            .joinValues()
            .map(
              ({length}) => [length, length === 1 ? 'item' : 'items'].join(' ')
            )
      );

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSource(this.todoListWithComplete)
      .toTarget(this.todoListFooterView.clearCompletedIsVisibleValue)
      .withTransform(
        (todoListWithCompletePayload) =>
          todoListWithCompletePayload
            .filter( ([, isCompleted]) => isCompleted )
            .joinValues()
            .map( ({length}) => length > 0 )
      );

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSources(
        this.todoListFooterView.clearCompletedClickEvt,
        this.todoListWithComplete
      )
      .toTarget(this.todoSet)
      .withTransform(
        ([clearCompletedPayload, todoListWithCompletePayload]) =>
          todoListWithCompletePayload
            .replaceByNoOp(clearCompletedPayload)
            .filter( ([, isCompleted]) => !isCompleted )
            .map( ([todo]) => todo )
      );

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSource(this.todoSet)
      .toTarget(this.todoListFooterView.isVisibleValue)
      .withTransform(
        (todoListPayload) =>
          todoListPayload.joinValues().map( ({length}) => length > 0 )
      );
  }
}
