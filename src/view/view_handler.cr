require "./view_handler_interface"

ADI.bind format_handlers : Array(Athena::Routing::View::FormatHandlerInterface), "!athena.format_handler"

@[ADI::Register]
class Athena::Routing::View::ViewHandler
  include Athena::Routing::View::ViewHandlerInterface

  # Only built in supported type at the moment is JSON.
  @formats = Set{"json"}

  @custom_handlers = Hash(String, ART::View::ViewHandlerInterface::HandlerType).new

  def initialize(
    @url_generator : ART::URLGeneratorInterface,
    @serializer : ASR::SerializerInterface,
    @request_store : ART::RequestStore,
    format_handlers : Array(Athena::Routing::View::FormatHandlerInterface),
    @empty_content_status : HTTP::Status = HTTP::Status::NO_CONTENT
  )
    format_handlers.each do |format_handler|
      self.register_handler format_handler.format, format_handler
    end
  end

  def register_handler(format : String, &block : ART::View::ViewHandlerInterface, ART::View, HTTP::Request, String -> ART::Response) : Nil
    self.register_handler format, &block
  end

  def register_handler(format : String, handler : ART::View::ViewHandlerInterface::HandlerType) : Nil
    @custom_handlers[format] = handler
  end

  # :inherit:
  def supports?(format : String) : Bool
    @custom_handlers.has_key?(format) || @formats.includes?(format)
  end

  # :inherit:
  def handle(view : ART::View, request : HTTP::Request? = nil) : ART::Response
    request = @request_store.request if request.nil?

    format = view.format || request.format

    unless self.supports? format
      raise ART::Exceptions::UnsupportedMediaType.new "Format '#{format}' has no built in handler.  A custom handler must be implemented."
    end

    if custom_handler = @custom_handlers[format]?
      return custom_handler.call self, view, request, format
    end

    self.create_response view, request, format
  end

  # :inherit:
  def create_response(view : ART::View, request : HTTP::Request, format : String) : ART::Response
    view.route.try do |route|
      if location = route ? @url_generator.generate(route, view.route_params, :absolute_url) : view.location
        return self.create_redirect_response view, location, format
      end
    end

    response = self.init_response view, format

    unless response.headers.has_key? "content-type"
      # TODO: Support setting content-type header based on the negotiated format.

      response.headers["content-type"] = "application/json; charset=UTF-8"
    end

    response
  end

  # :inherit:
  def create_redirect_response(view : ART::View, location : String, format : String) : ART::Response
    content = nil

    if (vs = view.status) && (vs.created? || vs.accepted?) && !view.data.nil?
      response = self.init_response view, format
    else
      status = self.status view, content
      response = ART::RedirectResponse.new location, status, view.headers
    end

    response
  end

  private def init_response(view : ART::View, format : String) : ART::Response
    content = nil

    # Skip serialization if the action's return type is explicitly `Nil`.
    unless view.return_type == Nil
      # TODO: Support Form typed views.
      data = view.data

      content = @serializer.serialize data, format, view.context
    end

    response = view.response
    response.status = self.status view, content

    response.content = content unless content.nil?

    response
  end

  private def status(view : ART::View, content : _) : HTTP::Status
    # TODO: Handle validating Form data.

    if status = view.status
      return status
    end

    content.nil? ? @empty_content_status : HTTP::Status::OK
  end
end