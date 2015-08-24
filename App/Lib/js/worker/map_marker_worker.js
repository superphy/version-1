
    onmessage = function(map) {
      console.log(map)
      var circleIcon, marker, markerList, marker_id, masterObject, newMarkers;
      masterObject = JSON.parse(map.data);
      markerList = masterObject['list'];
      circleIcon = masterObject['circle'];
      clusteredMarkers = [];
      for (marker_id in markerList) {
        marker = markerList[marker_id];
        marker.setIcon(circleIcon);
        _this.clusteredMarkers.push(marker);
      }
      newMarkers = JSON.stringify(_this.clusteredMarkers);
      return postMessage(newMarkers);
    };
