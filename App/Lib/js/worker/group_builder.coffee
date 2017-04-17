onmessage= (uGpObj) =>
  uGpObj = JSON.parse(uGpObj.data);
  

  groupHash = {}
  for group_collection, group_collection_index of uGpObj.standard
    groupHash[group_collection_index.name] = {}
    for group in group_collection_index.children
      groupHash[group_collection_index.name][group.name]={}
      if group.type is "collection"
        groupHash[group_collection_index.name][group.name]['type'] = 'collection'
        for level1 in group.children
          groupHash[group_collection_index.name][group.name][level1.name]= {}
          if level1.type is "collection"
            groupHash[group_collection_index.name][group.name][level1.name]['type'] = 'collection'
            for level2 in level1.children
              groupHash[group_collection_index.name][group.name][level1.name][level2.name] = {}
              if level2.type is "group"
                groupHash[group_collection_index.name][group.name][level1.name][level2.name] = {}
                groupHash[group_collection_index.name][group.name][level1.name][level2.name]['id'] = level2.id
                groupHash[group_collection_index.name][group.name][level1.name][level2.name]['type'] = level2.type
          if level1.type is "group"
            groupHash[group_collection_index.name][group.name][level1.name]['id'] = level1.id
            groupHash[group_collection_index.name][group.name][level1.name]['type'] = level1.type
      if group.type is "group"
        groupHash[group_collection_index.name][group.name] = {}
        groupHash[group_collection_index.name][group.name]['id'] = group.id
        groupHash[group_collection_index.name][group.name]['type'] = group.type
         
  

  table = "<ol class='group-list' genome_list='public'>" 

  #looping throught the main categories, ex: serotypes, host, syndrome ...
  for level0Key in Object.keys(groupHash).sort()
    table += "<li id=#{level0Key} data-value='false'><label style='font-weight:normal;margin-top:2px;margin-left:5px;'>#{level0Key}</label>"
    table += "<ol>"

    #looping throught the level1, ex: Homo Sapiens, 1c
    for level1key in Object.keys(groupHash[level0Key]).sort()
      level1 = groupHash[level0Key][level1key]
      if level1['type'] is 'collection'
        table += "<li id=#{level1key} data-value='false'><label style='font-weight:normal;margin-top:2px;margin-left:5px;'>#{level1key}</label>"
        table += "<ol>" 

        #loop through categories inside, here this is to show the serotype collections
        for level2key in Object.keys(groupHash[level0Key][level1key]).sort()
          level2 = groupHash[level0Key][level1key][level2key]
          if level2['type'] is "collection"
            table += "<li id=#{level2key} data-value='false'><label style='font-weight:normal;margin-top:2px;margin-left:5px;'>#{level2key}</label>"
            table += "<ol>"

            #list through the serotype collections
            for level3key in Object.keys(groupHash[level0Key][level1key][level2key]).sort()
              level3 = groupHash[level0Key][level1key][level2key][level3key]
              if level3['type'] is "group"
                table += "<li id=\"bonsai#{level2['id']}\"  data-value=#{level3['id']} data-collection_name=#{level2key} data-group_name=#{level3key}><label style='font-weight:normal;line-height:100%;'>#{level3key}</label></li>"
            table += "</ol></li>"
          if level2['type'] is "group"
            table += "<li id=\"bonsai#{level2['id']}\"  data-value=#{level2['id']} data-collection_name=#{level1key} data-group_name=#{level2key}><label style='font-weight:normal;line-height:100%;'>#{level2key}</label></li>"
        table += "</ol></li>"
      if level1['type'] is "group"
        #console.log "Add group level group"+group.name+" under "+group_collection_index.name
        table += "<li id=\"bonsai#{level1['id']}\"  data-value=#{level1['id']} data-collection_name=#{level0Key} data-group_name=#{level1key}><label style='font-weight:normal;line-height:100%;'>#{level1key}</label></li>"
    table += "</ol></li>"
  table = table + "</ol>"

  postMessage(table)
  return 0

