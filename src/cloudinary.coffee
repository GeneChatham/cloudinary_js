

###
  Main Cloudinary class

  Backward compatibility:
  Must provide public keys
   * CF_SHARED_CDN
   * OLD_AKAMAI_SHARED_CDN
   * AKAMAI_SHARED_CDN
   * SHARED_CDN
   * config
   * url
   * video_url
   * video_thumbnail_url
   * transformation_string
   * image
   * video_thumbnail
   * facebook_profile_image
   * twitter_profile_image
   * twitter_name_profile_image
   * gravatar_image
   * fetch_image
   * video
   * sprite_css
   * responsive
   * calc_stoppoint
   * device_pixel_ratio
   * supported_dpr_values

###
class Cloudinary
  CF_SHARED_CDN = "d3jpl91pxevbkh.cloudfront.net";
  OLD_AKAMAI_SHARED_CDN = "cloudinary-a.akamaihd.net";
  AKAMAI_SHARED_CDN = "res.cloudinary.com";
  SHARED_CDN = AKAMAI_SHARED_CDN;
  DEFAULT_POSTER_OPTIONS = { format: 'jpg', resource_type: 'video' };
  DEFAULT_VIDEO_SOURCE_TYPES = ['webm', 'mp4', 'ogv'];
  device_pixel_ratio_cache = {}

  ###*
  # Defaults values for parameters.
  #
  # (Previously defined using option_consume() )
  ###
  DEFAULT_IMAGE_PARAMS ={
    resource_type: "image"
    transformation: []
    type: 'upload'
  }

  ###*
  # Defaults values for parameters.
  #
  # (Previously defined using option_consume() )
  ###
  DEFAULT_VIDEO_PARAMS ={
    fallback_content: ''
    resource_type: "video"
    source_transformation: {}
    source_types: DEFAULT_VIDEO_SOURCE_TYPES
    transformation: []
    type: 'upload'
  }

  ###*
   * Return the resource type and action type based on the given configuration
   * @param resource_type
   * @param type
   * @param url_suffix
   * @param use_root_path
   * @param shorten
   * @returns {string} resource_type/type ###
  finalize_resource_type = (resource_type,type,url_suffix,use_root_path,shorten) ->
    if _.isPlainObject(resource_type)
      options = resource_type
      resource_type = options.resource_type
      type = options.type
      url_suffix = options.url_suffix
      use_root_path = options.use_root_path
      shorten = options.shorten

    type?='upload'
    if url_suffix?
      if resource_type=='image' && type=='upload'
        resource_type = "images"
        type = null
      else if resource_type== 'raw' && type== 'upload'
        resource_type = 'files'
        type = null
      else
        throw new Error("URL Suffix only supported for image/upload and raw/upload")
    if use_root_path
      if (resource_type== 'image' && type== 'upload' || resource_type == "images")
        resource_type = null
        type = null
      else
        throw new Error("Root path only supported for image/upload")
    if shorten && resource_type== 'image' && type== 'upload'
      resource_type = 'iu'
      type = null
    [resource_type,type].join("/")

  absolutize = (url) ->
    if !url.match(/^https?:\//)
      prefix = document.location.protocol + '//' + document.location.host
      if url[0] == '?'
        prefix += document.location.pathname
      else if url[0] != '/'
        prefix += document.location.pathname.replace(/\/[^\/]*$/, '/')
      url = prefix + url
    url

  cloudinary_url = (public_id, options = {}) ->
    _.defaults(options, @configuration.defaults(), DEFAULT_IMAGE_PARAMS)
    if options.type == 'fetch'
      options.fetch_format = options.fetch_format or options.format
      public_id = absolutize(public_id)

    transformation = new Transformation(options)
    transformation_string = transformation.flatten()

    throw 'Unknown cloud_name' unless options.cloud_name

    throw 'URL Suffix only supported in private CDN' if options.url_suffix and !options.private_cdn

    # if public_id has a '/' and doesn't begin with v<number> and doesn't start with http[s]:/ and version is empty
    if public_id.search('/') >= 0 and !public_id.match(/^v[0-9]+/) and !public_id.match(/^https?:\//) and !options.version?.toString()
      options.version = 1

    if public_id.match(/^https?:/)
      if options.type == 'upload' or options.type == 'asset'
        url = public_id
      else
        public_id = encodeURIComponent(public_id).replace(/%3A/g, ':').replace(/%2F/g, '/')
    else
      # Make sure public_id is URI encoded.
      public_id = encodeURIComponent(decodeURIComponent(public_id)).replace(/%3A/g, ':').replace(/%2F/g, '/')
      if options.url_suffix
        if options.url_suffix.match(/[\.\/]/)
          throw 'url_suffix should not include . or /'
        public_id = public_id + '/' + options.url_suffix
      if options.format
        if !options.trust_public_id
          public_id = public_id.replace(/\.(jpg|png|gif|webp)$/, '')
        public_id = public_id + '.' + options.format

    prefix = cloudinary_url_prefix(public_id, options)
    resource_type_and_type = finalize_resource_type(options.resource_type, options.type, options.url_suffix, options.use_root_path, options.shorten)
    version = if options.version then 'v' + options.version else ''

#    transformation.toHtmlTagOptions(options) # backward compatibility - options is mutated

    url ||  _.filter([
      prefix
      resource_type_and_type
      transformation_string
      version
      public_id
    ], null).join('/').replace(/([^:])\/+/g, '$1/')

  constructor: (options)->
    @configuration = new CloudinaryConfiguration(options)

  # Provided for backward compatibility
  config: (new_config, new_value) ->
    @configuration.config(new_config, new_value)

  # Generate a resource URL
  url: (public_id, options) ->
    options = _.cloneDeep( options)
    cloudinary_url.call this, public_id, options
  video_url: (public_id, options) ->
    options = _.merge({ resource_type: 'video' }, options)
    cloudinary_url.call this,  public_id, options
  video_thumbnail_url: (public_id, options) ->
    options = _.merge({}, DEFAULT_POSTER_OPTIONS, options)
    cloudinary_url.call this, public_id, options
  url_internal: cloudinary_url
  transformation_string: (options) ->
    options = _.cloneDeep( options)
    generate_transformation_string options
  image: (public_id, options={}) ->
    options = _.defaults(_.cloneDeep(options),@configuration.defaults(), DEFAULT_IMAGE_PARAMS)
    src = cloudinary_url.call(this, public_id, options)
    options["src"] = src
    new ImageTag(options).toHtml()

  video_thumbnail: (public_id, options) ->
    image public_id, _.extend( {}, DEFAULT_POSTER_OPTIONS, options)

  facebook_profile_image: (public_id, options) ->
    @image public_id, _.merge({ type: 'facebook' }, options)
  twitter_profile_image: (public_id, options) ->
    @image public_id, _.merge({ type: 'twitter' }, options)
  twitter_name_profile_image: (public_id, options) ->
    @image public_id, _.merge({ type: 'twitter_name' }, options)
  gravatar_image: (public_id, options) ->
    @image public_id, _.merge({ type: 'gravatar' }, options)
  fetch_image: (public_id, options) ->
    @image public_id, _.merge({ type: 'fetch' }, options)
  video: (public_id, options = {}) ->
    options = _.defaults(_.cloneDeep(options),@configuration.defaults(), DEFAULT_VIDEO_PARAMS)
    public_id = public_id.replace(/\.(mp4|ogv|webm)$/, '')

    source_types = options['source_types']
    source_transformation = options['source_transformation']
    fallback = options['fallback_content']

    video_options = _.cloneDeep(options)
    if video_options.hasOwnProperty('poster')
      if _.isPlainObject(video_options.poster) # else assume it is a literal poster string or `false`
        if video_options.poster.hasOwnProperty('public_id')
          # poster is a regular image
          video_options.poster = cloudinary_url.call( this, video_options.poster.public_id, video_options.poster)
        else # use the same public_id as the video, with video defaults
          video_options.poster = cloudinary_url.call( this, public_id, _.defaults( video_options.poster, DEFAULT_POSTER_OPTIONS))
    else
      video_options.poster = cloudinary_url.call( this, public_id, _.defaults( options, DEFAULT_POSTER_OPTIONS))
    if !video_options.poster
      delete video_options.poster
    poster = video_options.poster # TODO handle video attributes

    source = public_id

    unless  _.isArray(source_types)
      video_options.src = @url( "#{source}.#{source_types}", video_options)
    attributes = new Transformation(video_options).toHtmlTagOptions()
    attributes.poster = poster # TODO handle video attributes
    html = '<video ' + html_attrs(attributes) + '>'
    if _.isArray(source_types)
      i = 0
      while i < source_types.length
        source_type = source_types[i]
        transformation = source_transformation[source_type] or {}
        src = @url( "#{source }",
            _.defaults({ resource_type: 'video', format: source_type},
                      options,
                      transformation))
        video_type = if source_type == 'ogv' then 'ogg' else source_type
        mime_type = 'video/' + video_type
        html = html + '<source ' + html_attrs(
            src: src
            type: mime_type) + '>'
        i++
    html = html + fallback
    html = html + '</video>'
    html
  sprite_css: (public_id, options) ->
    options = _.merge({ type: 'sprite' }, options)
    if !public_id.match(/.css$/)
      options.format = 'css'
    @url public_id, options
  responsive: (options) ->
    responsive_config = _.merge(responsive_config or {}, options)
    $('img.cld-responsive, img.cld-hidpi').cloudinary_update responsive_config
    responsive_resize = get_config('responsive_resize', responsive_config, true)
    if responsive_resize and !responsive_resize_initialized
      responsive_config.resizing = responsive_resize_initialized = true
      timeout = null
      $(window).on 'resize', ->
        debounce = get_config('responsive_debounce', responsive_config, 100)

        reset = ->
          if timeout
            clearTimeout timeout
            timeout = null
          return

        run = ->
          $('img.cld-responsive').cloudinary_update responsive_config
          return

        wait = ->
          reset()
          setTimeout (->
            reset()
            run()
            return
          ), debounce
          return

        if debounce
          wait()
        else
          run()
        return
    return
  calc_stoppoint: (element, width) ->
    stoppoints = $(element).data('stoppoints') or @config().stoppoints or default_stoppoints
    if typeof stoppoints == 'function'
      return stoppoints(width)
    if typeof stoppoints == 'string'
      stoppoints = _.map(stoppoints.split(','), (val) ->
        parseInt val
      )
    closest_above stoppoints, width
  device_pixel_ratio: ->
    dpr = window.devicePixelRatio or 1
    dpr_string = device_pixel_ratio_cache[dpr]
    if !dpr_string
      # Find closest supported DPR (to work correctly with device zoom)
      dpr_used = closest_above(@supported_dpr_values, dpr)
      dpr_string = dpr_used.toString()
      if dpr_string.match(/^\d+$/)
        dpr_string += '.0'
      device_pixel_ratio_cache[dpr] = dpr_string
    dpr_string
  supported_dpr_values: [
    0.75
    1.0
    1.3
    1.5
    2.0
    3.0
  ]

  default_stoppoints = (width) ->
    10 * Math.ceil(width / 10)
  closest_above = (list, value) ->
    i = list.length - 2
    while i >= 0 and list[i] >= value
      i--
    list[i + 1]

  # Produce a number between 1 and 5 to be used for cdn sub domains designation
  cdn_subdomain_number = (public_id)->
    crc32(public_id) % 5 + 1

  #  * cdn_subdomain - Boolean (default: false). Whether to automatically build URLs with multiple CDN sub-domains. See this blog post for more details.
  #  * private_cdn - Boolean (default: false). Should be set to true for Advanced plan's users that have a private CDN distribution.
  #  * secure_distribution - The domain name of the CDN distribution to use for building HTTPS URLs. Relevant only for Advanced plan's users that have a private CDN distribution.
  #  * cname - Custom domain name to use for building HTTP URLs. Relevant only for Advanced plan's users that have a private CDN distribution and a custom CNAME.
  #  * secure - Boolean (default: false). Force HTTPS URLs of images even if embedded in non-secure HTTP pages.
  cloudinary_url_prefix = (public_id, options) ->
    return '/res'+options.cloud_name if options.cloud_name?.indexOf("/")==0

    # defaults
    protocol = "http://"
    cdn_part = ""
    subdomain = "res"
    host = ".cloudinary.com"
    path = "/" + options.cloud_name

    # modifications
    if options.protocol
      protocol = options.protocol + '//'
    else if window?.location?.protocol == 'file:'
      protocol = 'file://'

    if options.private_cdn
      cdn_part = options.cloud_name + "-"
      path = ""

    if options.cdn_subdomain
      subdomain = "res-" + cdn_subdomain_number(public_id)

    if options.secure
      protocol = "https://"
      subdomain = "res" if options.secure_cdn_subdomain == false
      if options.secure_distribution? &&
         options.secure_distribution != OLD_AKAMAI_SHARED_CDN &&
         options.secure_distribution != SHARED_CDN
        cdn_part = ""
        subdomain = ""
        host = options.secure_distribution

    else if options.cname
      protocol = "http://"
      cdn_part = ""
      subdomain = if options.cdn_subdomain then 'a'+((crc32(public_id)%5)+1)+'.' else ''
      host = options.cname
#      path = ""

    [protocol, cdn_part, subdomain, host, path].join("")

  join_pair = (key, value) ->
    if !value
      undefined
    else if value == true
      key
    else
      key + '="' + value + '"'

  ###*
  # combine key and value from the `attr` to generate an HTML tag attributes string.
  # `Transformation::toHtmlTagOptions` is used to filter out transformation and configuration keys.
  # @param {Object} attr
  # @return {String} the attributes in the format `'key1="value1" key2="value2"'`
  ###
  html_attrs = (attrs) ->
    pairs = _.map(attrs, (value, key) ->
      join_pair key, value
    )
    pairs.sort()
    pairs.filter((pair) ->
      pair
    ).join ' '

  unsigned_upload_tag = (upload_preset, upload_params, options) ->
    $('<input/>').attr(
      type: 'file'
      name: 'file').unsigned_cloudinary_upload upload_preset, upload_params, options

if module?.exports
#On a server
  exports.Cloudinary = Cloudinary
else
#On a client
  window.Cloudinary = Cloudinary

if window.jQuery?
  window.jQuery.cloudinary = new Cloudinary()