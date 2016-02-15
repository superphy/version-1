onmessage = (map) =>
	console.log(map)
	masterObject = JSON.parse(map)
	markerList = masterObject['list']
	circleIcon = masterObject['circle']
	map = masterObject['map']
	clusteredMarkers = []
	# Needs to be called after selection is updated
	for marker_id, marker of markerList
		marker.setMap(map)
		marker.setIcon(circleIcon)
		@clusteredMarkers.push(marker)

	newMarkers = JSON.stringify(@clusteredMarkers)
	postMessage(newMarkers)