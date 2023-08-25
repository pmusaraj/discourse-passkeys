import Component from "@glimmer/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

export default class RenamePasskey extends Component {
  @service dialog;
  @tracked passkeyName;

  constructor() {
    super(...arguments);
    this.passkeyName = this.args.model.name;
  }

  @action
  saveRename() {
    ajax(`/passkeys/rename/${this.args.model.id}`, {
      type: "POST",
      data: {
        name: this.passkeyName,
      },
    }).then(() => {
      window.location.reload();
    });
  }
}
