/*
  OpenACS Attachments via the attachments package
*/
(()=>{
  const name = 'oacsAttachments';
  const pluginURL = '/attachments/richtext/file-browser';

  tinymce.PluginManager.add(name, (editor, url) => {

    let title = 'Attachments';

    /* Register the parameters we expect to receive in the editor's JSON
     * conf. Without registering we won't have the chance to access
     * them. */
    editor.options.register('package_id', {
      processor: 'integer',
      default: 0
    });
    editor.options.register('object_id', {
      processor: 'integer',
      default: editor.options.get('package_id')
    });

    const objectId = editor.options.get('object_id');

    /* We cann the plugin URL and read its localized information */
    const req = new XMLHttpRequest();
    req.responseType = 'json';
    req.addEventListener('load', () => {
      if (req.status === 200) {
        console.log(req);
        title = req.response.title;

        /* Add a button that opens a window */
        editor.ui.registry.addButton(name, {
          tooltip: title,
          icon: 'browse',
          onAction: openDialog
        });
        /* Adds a menu item, which can then be included in any menu via the
         * menu/menubar configuration */
        editor.ui.registry.addMenuItem(name, {
          text: title,
          icon: 'browse',
          onAction: openDialog
        });
      }
    });
    req.open('GET', pluginURL);
    req.send();

    let iframe;

    /* This plugin simply opens a window to the custom URL */
    const openDialog = () => {
      editor.windowManager.openUrl({
        title: title,
        url: `${pluginURL}?object_id=${objectId}`
      });

      /* Obtain a reference to the plugin iframe we just opened. */
      const iframes = document.querySelectorAll('iframe');
      if (iframes.length === 0) { return; }

      const lastIframe = iframes[iframes.length - 1];
      const src = lastIframe.getAttribute('src');
      if (src === `${pluginURL}?object_id=${objectId}`) {
        iframe = lastIframe;
      }
    };

    window.addEventListener('message', function (evt) {
      /* This listener is delegated, so it will trigger for every
       * editor/plugin combination. We need to filter events that are
       * relevant to us */
      if (tinymce.activeEditor !== editor || evt.data.plugin !== name) {
        return;
      }

      switch (evt.data.action) {
      case 'insertContent':
        editor.insertContent(` ${evt.data.content} `);
        editor.windowManager.close();
        break;
      case 'close':
        editor.windowManager.close();
        break;
      }
    });

    return {
      getMetadata: () => ({
        name: `${title} plugin`,
        url: 'https://openacs.org'
      })
    };
  });
})();

//
// Local variables:
//    mode: javascript
//    js-indent-level: 2
//    indent-tabs-mode: nil
// End:
//
