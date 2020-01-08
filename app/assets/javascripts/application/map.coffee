$(document)
  .on 'turbolinks:load', ->
    $map = $('.page-map-content')
    return unless $map.length > 0

    $.get $map.data('url'), (response) ->
      return unless response.bounds?

      $map.show()
      map = L.map('map').setView($map.data('center'), 13)

      L.tileLayer($map.data('tile_layer'), {attribution: $map.data('attribution')}).addTo(map)

      p1 = L.latLng(response.bounds.min_lat, response.bounds.min_long)
      p2 = L.latLng(response.bounds.max_lat, response.bounds.max_long)
      map.fitBounds(L.latLngBounds(p1, p2))

      $.get $map.data('photos_url'), (response) ->
        markers = L.markerClusterGroup()

        for photo in response
          width = photo.image_size[0]
          height = photo.image_size[1]

          imgWidth = width * 200 / height
          imgWidth = 200 if imgWidth > 200
          imgHeight = height * imgWidth / width

          marker = L.marker(
            [photo.lat_long.x, photo.lat_long.y],
            title: photo.name
          ).bindPopup(
            "<div class=\"photo-popup\"><h3>#{photo.name}</h3><a href=\"#{photo.url}\" target=\"_blank\">" +
            "<img style=\"width: #{imgWidth}px; height: #{imgHeight}px\" src=\"#{photo.preview}\"></a></div>"
          )

          markers.addLayer(marker)

        map.addLayer(markers)

      $.get $map.data('tracks_url'), (response) ->
        return unless response.length > 0
        tracks = {}

        for track in response
          new L.GPX(
            track.url,
            async: true,
            marker_options:
              clickable: true
              startIconUrl: 'https://raw.githubusercontent.com/mpetazzoni/leaflet-gpx/master/pin-icon-start.png',
              endIconUrl: 'https://raw.githubusercontent.com/mpetazzoni/leaflet-gpx/master/pin-icon-end.png',
              shadowUrl: 'https://raw.githubusercontent.com/mpetazzoni/leaflet-gpx/master/pin-shadow.png'
            polyline_options:
              color: track.color
          ).on('loaded', ((e) ->
              tracks[this.id] = e.target

              if Object.keys(tracks).length == response.length
                control = L.control.layers(null, null).addTo(map)
                for value in response
                  gpx = tracks[value.id]
                  control.addOverlay(gpx, value.name)
            ).bind(track)
          ).addTo(map)
