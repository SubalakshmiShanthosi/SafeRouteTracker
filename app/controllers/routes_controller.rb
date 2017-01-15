class RoutesController < ApplicationController

  def index
  end


  def locations
    render json: Location.all.collect(&:name), status: :ok
  end

  def air_quality_marker
    area_id_map = {'alandur' => '3757', 'IIT' => '8184', 'Manali' => '8185'}
    base_url = 'https://api.waqi.info/api/feed/@'
    results = []
    area_id_map.each { |k, v|
      air_pollution_response = get_api_response(base_url + v + '/now.json')
      results << {latitude: air_pollution_response['rxs']['obs'][0]['msg']['city']['geo'][0].to_f, longitude: air_pollution_response['rxs']['obs'][0]['msg']['city']['geo'][1].to_f, value: air_pollution_response['rxs']['obs'][0]['msg']['aqi'], status: air_pollution_response['rxs']['status'], area: k}
    }
    render json: results, status: :ok
  end

  def safe_path

    api_key = 'AIzaSyAYU_fYcPQGp1FnLfH4W0F07hofMQkvZcQ'
    origin = params[:from] ? params[:from].gsub(" ", "%20;") + ',Chennai' : 'thiruvanmiyur,IN'
    destination = params[:to] ? params[:to].gsub(' ', '%20;') + ',Chennai': 'tambaram,IN'
    url = "https://maps.googleapis.com/maps/api/directions/json?origin=#{origin}&destination=#{destination}&key=#{api_key}&alternatives=true"
    paths = []

    lat_long_list = []
    routes_json = get_api_response(url)
    routes_json["routes"].each do |route|
      ne_bound = route["bounds"]["northeast"]
      sw_bound = route["bounds"]["southwest"]
      path = Path.new(start_point: origin, end_point: destination, occurences: 0, unsafe_measure: 0, bounds: [ne_bound,sw_bound])
      path = traverse(route, path)
      paths << path
    end
    routes = categorised_routes(paths)
    route_bounds = []
    routes[0].each do |route|
      route_bounds << {"bounds"=>[{"lat"=>route.bounds[0]["lat"],"lng"=>route.bounds[0]["lng"]},
                                  {"lat"=>route.bounds[1]["lat"],"lng"=>route.bounds[1]["lng"]}]
      }
    end
    routes[1].each do |route|
      route_bounds << [{"lat"=>route.bounds[0]["lat"],"lng"=>route.bounds[0]["lng"]},
                                  {"lat"=>route.bounds[1]["lat"],"lng"=>route.bounds[1]["lng"]}]
      end

    returned_route_bounds = route_bounds[1]
    selected_routes = routes_json["routes"].select { |route| route["bounds"]["northeast"]["lat"].to_f == returned_route_bounds[0]["lat"].to_f && route["bounds"]["southwest"]["lat"].to_f == returned_route_bounds[1]["lat"].to_f && route["bounds"]["northeast"]["lng"].to_f == returned_route_bounds[0]["lng"].to_f && route["bounds"]["southwest"]["lng"].to_f == returned_route_bounds[1]["lng"].to_f }
    selected_routes.each do |selected_route|
      selected_route['legs'].each do |leg|
        leg['steps'].each do |step|
          lat_long_list << {lat: step['start_location']['lat'].to_f, lng: step['start_location']['lng'].to_f}
          lat_long_list << {lat: step['end_location']['lat'].to_f, lng: step['end_location']['lng'].to_f}
        end
      end
    end

    render json: lat_long_list, status: :ok
  end
  def traverse(route, path)
    points = []
    route["legs"].each do |leg|
      leg["steps"].each do |step|
        start_point_lat = step["start_location"]["lat"]
        start_point_long = step["start_location"]["lng"]
        crisis_locations = Location.all
        update_path(crisis_locations, path, start_point_lat, start_point_long) unless points.include?([start_point_lat,start_point_long])
        points << [start_point_lat, start_point_long]
        end_point_lat = step["end_location"]["lat"]
        end_point_long = step["end_location"]["lng"]
        update_path(crisis_locations, path, end_point_lat, end_point_long) unless points.include?([end_point_lat,end_point_long])
        points << [end_point_lat, end_point_long]
      end
    end
    path
  end

  def get_api_response(url)
    resource = RestClient::Resource.new(url)
    response = resource.get
    JSON.parse(response.body)
  end

  def categorised_routes(paths)
    minimum_occurence = paths.collect(&:occurences).min
    minimum_weightage = paths.collect(&:unsafe_measure).min
    routes_with_min_occurence = paths.select {|path| path.occurences == minimum_occurence}
    if minimum_occurence == 0
      [routes_with_min_occurence,nil]
    else
      routes_with_min_unsafe_measure = paths.select {|path| path.unsafe_measure == minimum_weightage}
      [routes_with_min_occurence,routes_with_min_unsafe_measure]
    end
  end

  def distance(lat1, lon1, lat2, lon2)
    latitude1 = lat1.to_f
    longitude1 = lon1.to_f
    latitude2 = lat2.to_f
    longitude2 = lon2.to_f
    @ConstantR = 6371;
    dLat = (latitude2-latitude1) * Math::PI / 180;
    dLon = (longitude2-longitude1) * Math::PI / 180;
    a = Math.sin(dLat/2) * Math.sin(dLat/2) +
        Math.cos(latitude1 * Math::PI / 180) * Math.cos(latitude2 * Math::PI / 180) *
            Math.sin(dLon/2) * Math.sin(dLon/2);
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    d = @ConstantR * c;
    if (d>1)
      return d.round;
    elsif (d<=1)
      return (d*1000).round;
    else
      return d;
    end
  end

  def update_path(crisis_locations, path, latitude, longitude)
    matching_crisis_locations = crisis_locations.select { |loc| distance(loc.latitude, loc.longitude, latitude, longitude) < 10 }
    if matching_crisis_locations.present?
      path.occurences += 1
      path.unsafe_measure += matching_crisis_locations.first.occurences.to_i
    end
    path
  end
end
