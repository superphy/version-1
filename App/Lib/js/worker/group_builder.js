onmessage=function(uGpObj){

  uGpObj = JSON.parse(uGpObj.data);
	var group, group_collection, group_collection_index, len, len1, len2, level1, level2, q, ref, ref1, ref2, ref3, s, table, w;
      table = "<ol class='group-list' genome_list='public'>";
      ref = uGpObj.standard;
      for (group_collection in ref) {
        group_collection_index = ref[group_collection];
        table += "<li id=" + group_collection_index.name + " data-value='false'><label style='font-weight:normal;margin-top:2px;margin-left:5px;'>" + group_collection_index.name + "</label>";
        table += "<ol>";
        ref1 = group_collection_index.children;
        for (q = 0, len = ref1.length; q < len; q++) {
          group = ref1[q];
          if (group.type === "collection") {
            table += "<li id=" + group.name + " data-value='false'><label style='font-weight:normal;margin-top:2px;margin-left:5px;'>" + group.name + "</label>";
            table += "<ol>";
            ref2 = group.children;
            for (s = 0, len1 = ref2.length; s < len1; s++) {
              level1 = ref2[s];
              if (level1.type === "collection") {
                table += "<li id=" + level1.name + " data-value='false'><label style='font-weight:normal;margin-top:2px;margin-left:5px;'>" + level1.name + "</label>";
                table += "<ol>";
                ref3 = level1.children;
                for (w = 0, len2 = ref3.length; w < len2; w++) {
                  level2 = ref3[w];
                  if (level2.type === "group") {
                    table += "<li id=\"bonsai" + level2.id + "\"  data-value=" + level2.id + " data-collection_name=" + level1.name + " data-group_name=" + level2.name + "><label style='font-weight:normal;line-height:100%;'>" + level2.name + "</label></li>";
                  }
                }
                table += "</ol></li>";
              }
              if (level1.type === "group") {
                table += "<li id=\"bonsai" + level1.id + "\"  data-value=" + level1.id + " data-collection_name=" + group.name + " data-group_name=" + level1.name + "><label style='font-weight:normal;line-height:100%;'>" + level1.name + "</label></li>";
              }
            }
            table += "</ol></li>";
          }
          if (group.type === "group") {
            table += "<li id=\"bonsai" + group.id + "\"  data-value=" + group.id + " data-collection_name=" + group_collection_index.name + " data-group_name=" + group.name + "><label style='font-weight:normal;line-height:100%;'>" + group.name + "</label></li>";
          }
        }
        table += "</ol></li>";
      }
      table = table + "</ol>";
      postMessage(table);
    };
	