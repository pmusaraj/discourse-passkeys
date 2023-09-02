import { create, parseCreationOptionsFromJSON } from "../../lib/webauthn-json";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Component from "@glimmer/component";
import RenamePasskey from "discourse/plugins/discourse-passkeys/discourse/components/rename-passkey";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class UserPasskeys extends Component {
  @service dialog;
  @service currentUser;

  get isCurrentUser() {
    return this.currentUser.id === this.args.model.id;
  }

  @action
  addPasskey() {
    ajax("/passkeys/create-options.json")
      .then((response) => {
        const options = parseCreationOptionsFromJSON({ publicKey: response });

        create(options)
          .then((credential) => {
            // this is called after the browser has
            // - verified the user's identity
            // - generated a new credential
            // - ensured that the credential is unique
            ajax("/passkeys/register.json", {
              type: "POST",
              data: {
                publicKeyCredential: credential.toJSON(),
              },
            })
              .then((key) => {
                // Show rename alert after creating/saving new key
                this.dialog.dialog({
                  title: "Success! Passkey was created.",
                  type: "notice",
                  bodyComponent: RenamePasskey,
                  bodyComponentModel: key,
                });
              })
              .catch(popupAjaxError);
          })
          .catch((error) => {
            if (error.name === "InvalidStateError") {
              this.dialog.alert({
                message:
                  "Error: A passkey is already registered on this device. To register a new key, you must first delete the existing key from your device's security settings.",
              });
            } else if (error.name === "NotAllowedError") {
              // do nothing, user cancelled the operation
            } else {
              console.log({ error });
              popupAjaxError(error.message);
            }
          });
      })
      .catch(popupAjaxError);
  }

  @action
  deletePasskey(id) {
    this.dialog.deleteConfirm({
      title: "Are you sure you want to delete this passkey?",
      didConfirm: () => {
        ajax(`/passkeys/delete/${id}`, {
          type: "DELETE",
        }).then(() => {
          window.location.reload();
        });
      },
    });
  }

  @action
  renamePK(id, name) {
    this.dialog.dialog({
      title: "Rename Passkey",
      type: "notice",
      bodyComponent: RenamePasskey,
      bodyComponentModel: { id, name },
    });
  }
}
