require 'test_helper'

class RoutesControllerTest < ActionController::TestCase
  test "should get getRoutes" do
    get :getRoutes
    assert_response :success
  end

end
