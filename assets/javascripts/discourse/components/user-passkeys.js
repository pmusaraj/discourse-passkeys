import { create, parseCreationOptionsFromJSON } from "../../lib/webauthn-json";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class UserPasskeys extends Component {
  @service dialog;

  @action
  addPasskey() {
    ajax("/passkeys/create-options.json")
      .then((response) => {
        const options = parseCreationOptionsFromJSON({ publicKey: response });
        // console.log(options);

        create(options).then((credential) => {
          // console.log(JSON.stringify(credential));

          // this is called after the browser has verified the user's identity
          ajax("/passkeys/register.json", {
            type: "POST",
            data: {
              publicKeyCredential: credential.toJSON(),
            },
          })
            .then(() => {
              window.location.reload();
              // update UI properly to show registered keys
            })
            .catch(popupAjaxError);
          // TODO: handle errors with more detail?
        });
      })
      .catch(popupAjaxError);
  }

  @action
  deletePasskey() {
    this.dialog.deleteConfirm({
      title: "Are you sure you want to delete the passkey?",
      didConfirm: () => {
        ajax("/passkeys/delete-first", {
          type: "DELETE",
        }).then(() => {
          window.location.reload();
        });
      },
    });
  }
}
