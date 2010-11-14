var Storage = {
  data: { models: [] },

  guid: function() {
    return (new Date()).valueOf() + (Math.random() * 0x10000|0) + '';
  },

  ready: function() {},

  remote: {
    read: function() {
      Storage.ready();
      var data = {
          "collections": {
              "today": ["1289626659321"],
              "project_tasks_1289626641134": ["1289626626026"],
              "projects": ["1289626641134", "1289626670630"],
              "inbox": ["1289626693268"],
              "next": []
          },
          "projects": {
              "1289626641134": {
                  "name": "Project 1",
                  "notes": null,
                  "done": false,
                  "id": "1289626641134",
                  "tags": "tag1 tag2 tag3",
                  "user_id": "4cde23f94ecc2a6269000003"
              }
          },
          "tasks": {
              "1289626659321": {
                  "name": "Example task to do today",
                  "created_at": "2010-11-13T05:36:58Z",
                  "updated_at": "2010-11-13T05:36:58Z",
                  "project_id": null,
                  "archived": false,
                  "done": false,
                  "id": "1289626659321",
                  "user_id": "4cde23f94ecc2a6269000003"
              },
              "1289626626026": {
                  "name": "Example task",
                  "created_at": "2010-11-13T05:36:57Z",
                  "updated_at": "2010-11-13T20:35:36Z",
                  "project_id": "1289626641134",
                  "archived": false,
                  "done": false,
                  "id": "1289626626026",
                  "user_id": "4cde23f94ecc2a6269000003"
              }
          },
          "settings": {
              "outline-view": "#show-inbox"
          }
      }
      jQuery.each(data || [], function(index, value) {
        Storage.data[index] = value;
      });
          
    },

    create: function(collection, json) {
      jQuery.post('/storage', {
        data: JSON.stringify(json),
        collection: collection
      },
      function() {
      }, 'json');
    },

    update: function(collection, json) {
      jQuery.post('/storage', {
        '_method': 'PUT',
        data: JSON.stringify(json),
        collection: collection
      },
      function() {
      }, 'json');
    },

    destroy: function(collection, json) {
      json['_method'] = 'DELETE';
      json['collection'] = collection;
      jQuery.post('/storage', json,
      function() {
      }, 'json');
    },

    setKey: function(collection, json) {
      jQuery.post('/storage/set_key_value', { '_method': 'PUT', collection: collection, data: JSON.stringify(json) },
      function() {
      }, 'json');
    }
  }
};

