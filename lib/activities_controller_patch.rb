# lib/activities_controler_patch.#!/usr/bin/env ruby -wKU

require_dependency 'activities_controller'

module ActivitiesControlerPatch
	def self.included(base)
		base.send(:include, InstanceMethods)
		
		base.accept_api_auth :index

		base.class_eval do
			unloadable 
			alias_method_chain :index, :api
		end
	end

	module InstanceMethods

		def index_with_api
			
		    @days = Setting.activity_days_default.to_i

		    if params[:from]
		      begin; @date_to = params[:from].to_date + 1; rescue; end
		    end

		    @date_to ||= Date.today + 1
		    @date_from = @date_to - @days
		    @with_subprojects = params[:with_subprojects].nil? ? Setting.display_subprojects_issues? : (params[:with_subprojects] == '1')
		    @author = (params[:user_id].blank? ? nil : User.active.find(params[:user_id]))

		    @activity = Redmine::Activity::Fetcher.new(User.current, :project => @project,
		                                                             :with_subprojects => @with_subprojects,
		                                                             :author => @author)
		    @activity.scope_select {|t| !params["show_#{t}"].nil?}
		    @activity.scope = (@author.nil? ? :default : :all) if @activity.scope.empty?

		    events = @activity.events(@date_from, @date_to)

		    if events.empty? || stale?(:etag => [@activity.scope, @date_to, @date_from, @with_subprojects, @author, events.first, events.size, User.current, current_language])
		      respond_to do |format|
		        format.html {
		          @events_by_day = events.group_by {|event| User.current.time_to_date(event.event_datetime)}
		          render :layout => false if request.xhr?
		        }
		        format.atom {
		          title = l(:label_activity)
		          if @author
		            title = @author.name
		          elsif @activity.scope.size == 1
		            title = l("label_#{@activity.scope.first.singularize}_plural")
		          end
		          render_feed(events, :title => "#{@project || Setting.app_title}: #{title}")
		        }
		        format.api {
		        	@events_by_day = events.group_by {|event| User.current.time_to_date(event.event_datetime)}
		        	#puts @events_by_day.to_json
		        }
		      end
		    end

		end
	end
end

ActivitiesController.send(:include, ActivitiesControlerPatch)