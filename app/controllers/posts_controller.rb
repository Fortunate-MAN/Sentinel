class PostsController < ApplicationController
  before_action :set_post, :only => [:show, :edit, :update, :destroy]
  before_action :authenticate_user!, :only => [:edit, :update, :destroy, :flag_options, :cast_flag]
  before_action :verify_admin, :only => [:edit, :update, :destroy]
  before_action :verify_bot_authorized, :only => [:create]
  before_action :verify_post_eligible, :only => [:flag_options, :cast_flag]
  skip_before_action :verify_authenticity_token, :only => [:create]

  def index
    @posts = Post.all.order(params[:sort] || 'created_at desc', 'id desc').paginate(:page => params[:page], :per_page => 100)
  end

  def create
    @post = Post.new post_params
    if @post.save
      params[:reasons].each do |reason|
        @reason = Reason.find_or_create_by(name: reason)
        @reason.posts << @post
        unless @reason.save
          render :json => { :status => "E:REASON_FAILED_TO_SAVE", :code => "500.2" }, :status => 500
        end
      end
      if @post.save
        # Expire the cached Reason#most_recent values explicitly so that they update immediately
        @post.reasons.each do |reason|
          Rails.cache.delete("reason_#{reason.id}_most_recent")
        end

        render :create, :formats => :json
      else
        render :json => { :status => "E:POST_FAILED_TO_SAVE", :code => "500.3" }, :status => 500
      end
    else
      render :json => { :status => "E:POST_FAILED_TO_SAVE", :code => "500.1" }, :status => 500
    end
  end

  def show
  end

  def edit
  end

  def update
    if @post.update(post_params)
      redirect_to url_for(:controller => :posts, :action => :show, :id => @post.id)
    else
      render :edit
    end
  end

  def destroy
    if @post.destroy
      flash[:success] = "Removed post #{@post.id}."
      redirect_to url_for(:controller => :posts, :action => :index)
    else
      render :show
    end
  end

  def with_feedback
    @type = FeedbackType.find_by_short_code params[:type]
    @posts = @type.posts.paginate(:page => params[:page], :per_page => 100)
  end

  def flag_options
    response = HTTParty.get(api_url("/answers/#{params[:answer_id]}/flags/options", current_user, { :site => 'stackoverflow' }))
    render :json => response.body, :status => response.code
  end

  def cast_flag
    response = HTTParty.post(api_url("/answers/#{params[:answer_id]}/flags/add", current_user, { :site => 'stackoverflow' }),
                             :body => { :option_id => params[:option_id], :comment => params[:comment] })
    if response.code == 200
      flag = Flag.new(:post => Post.find_by_answer_id(params[:answer_id]), :user => current_user, :flag_type => params[:flag_type])
      unless flag.save
        render :json => { :error_message => flag.errors.full_messages.map{ |m| m.downcase! }.to_sentence.capitalize }, :status => 500
      end
    end
    render :json => response.body, :status => response.code
  end

  def not_flaggable
  end

  private
  def set_post
    @post = Post.find params[:id]
  end

  def post_params
    params.require(:post).permit(:title, :body, :link, :post_creation_date, :user_link, :username, :user_reputation, :nato_score)
  end

  def verify_post_eligible
    post = Post.find_by_answer_id params[:answer_id]
    unless post.majority_feedback.short_code == 'tp'
      render :not_flaggable, :status => 400, :formats => :json
    end
  end
end
