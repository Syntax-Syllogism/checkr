export class CloseActionScreenEvent extends CustomEvent {
  constructor() {
    super("closeactionscreenevent", {
      bubbles: true,
      composed: true,
      cancelable: false
    });
  }
}
