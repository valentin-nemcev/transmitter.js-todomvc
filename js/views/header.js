import * as Transmitter from 'transmitter-framework/index.es';

import {getKeycodeMatcher} from '../helpers';


const matchEnter = getKeycodeMatcher('enter');
const matchEscEnter = getKeycodeMatcher('enter', 'esc');


export default class HeaderView {

  constructor($element) {
    this.$element = $element;
    this.$newTodoInput = this.$element.find('.new-todo');

    this.newTodoLabelInputValue =
      new Transmitter.DOMElement.InputValue(this.$newTodoInput[0]);
    this.newTodoKeypressEvt =
      new Transmitter.DOMElement.DOMEvent(this.$newTodoInput[0], 'keyup');

    this.clearNewTodoLabelInputChannel =
      new Transmitter.Channels.SimpleChannel()
        .inForwardDirection()
        .fromSource(this.newTodoKeypressEvt)
        .toTarget(this.newTodoLabelInputValue)
        .withTransform(
          (keypressPayload) => matchEscEnter(keypressPayload).map( () => '' )
        );
  }

  init(tr) {
    this.clearNewTodoLabelInputChannel.init(tr);
    return this;
  }

  createTodosChannel(todos) {
    return new Transmitter.Channels.SimpleChannel()
    .inBackwardDirection()
    .fromSources(this.newTodoLabelInputValue, this.newTodoKeypressEvt)
    .toTarget(todos.todoSet)
    .withTransform(
      ([labelPayload, keypressPayload], tr) =>
        labelPayload
          .replaceByNoOp(matchEnter(keypressPayload))
          .map( (label) => todos.create().init(tr, {label}) )
          .toAppendAction()
    );
  }
}
