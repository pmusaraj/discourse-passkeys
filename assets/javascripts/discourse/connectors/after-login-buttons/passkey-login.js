import { get, parseRequestOptionsFromJSON } from "../../../lib/webauthn-json";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse-common/lib/get-url";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default {
  actions: {
    passkeyLogin() {
      ajax("/passkeys/challenge.json")
        .then((response) => {
          const options = parseRequestOptionsFromJSON({ publicKey: response });
          get(options)
            .then((credential) => {
              ajax("/passkeys/auth.json", {
                type: "POST",
                data: {
                  publicKeyCredential: credential.toJSON(),
                },
              }).then((res) => {
                if (res && res.failed) {
                  alert("Login failed");
                  return;
                }

                if (window.location.pathname === getURL("/login")) {
                  window.location = getURL("/");
                } else {
                  window.location.reload();
                }
              });
            })
            .catch(popupAjaxError);
        })
        .catch(popupAjaxError);
    },
  },
};
