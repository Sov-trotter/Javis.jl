
function render_sublayer_objects(objects, video, frame; layer_frames = nothing)
    CURRENT_OBJECT[1] = objects[1]
    background_settings = ObjectSetting()
    origin()
    origin_matrix = cairotojuliamatrix(getmatrix())
    # this frame needs doing, see if each of the scenes defines it
    for object in objects
        # if object is not in global layer this sets the background_settings
        # from the parent background object
        update_object_settings!(object, background_settings)
        CURRENT_OBJECT[1] = object

        if layer_frames !== nothing && (frame - first(get_frames(object)) - first(layer_frames.frames) - first(get_frames(CURRENT_LAYER[1])) + 3) in get_frames(object)

            # check if the object should be part of the global layer (i.e Background)
            # or in its own layer (default)
            in_global_layer = get(object.opts, :in_global_layer, false)::Bool
            in_local_layer = get(object.opts, :in_local_layer, false)::Bool
            if !in_global_layer && !in_local_layer
                @layer begin
                    draw_sublayer_object(object, video, frame, origin_matrix, layer_frames)
                end
            else
                draw_sublayer_object(object, video, frame, origin_matrix, layer_frames)
                # update origin_matrix as it's inside the global layer
                origin_matrix = cairotojuliamatrix(getmatrix())
            end

            # if object is in global layer this changes the background settings
            update_background_settings!(background_settings, object)
        end
    end
end

function get_sublayer_frame(video, layer, frame)
    layer_frames = layer.frames
    # render sub layers before hand
    Drawing(layer.width, layer.height, :image)
    render_sublayer_objects(layer.layer_objects, video, frame, layer_frames = layer_frames)

    if (frame - first(layer_frames.frames) - first(get_frames(CURRENT_LAYER[1])) + 3) in get_frames(layer)
        
        # call currently active actions and their transformations for each layer
        actions = layer.actions
        for action in actions
            get_frames(action) isa Nothing &&
                error("Frame range for the layer's action might be missing")
            rel_frame = frame - first(layer_frames.frames) - first(get_frames(CURRENT_LAYER[1]))
            if rel_frame in get_frames(action)
                action.func(video, layer, action, rel_frame)
            elseif rel_frame > last(get_frames(action)) && action.keep
                # call the action on the last frame i.e. disappeared things stay disappeared
                action.func(video, layer, action, last(get_frames(action)))
            end
        end
    end    
    img_layer = image_as_matrix()
    finish()
    return img_layer
end

function render_sublayers(sublayers, video, frame; layer_frames = nothing)
    for sublayer in sublayers
        if layer_frames !== nothing && (frame - first(layer_frames.frames) + 1) in get_frames(sublayer)
            sublayer.image_matrix = get_sublayer_frame(video, sublayer, frame)
        end
    end
end

function place_sublayers(sublayers, frame; layer_frames=nothing)
    for sublayer in sublayers
        if layer_frames !== nothing && (frame - first(layer_frames.frames) + 1) in get_frames(sublayer)
            pt = centered_point(sublayer.position, sublayer.width, sublayer.height)
            @layer begin
                # any actions on the layer go in this block
                sublayer_settings = sublayer.current_setting
                apply_layer_settings(sublayer_settings, sublayer.position)
                placeimage(sublayer.image_matrix, pt, alpha = sublayer.current_setting.opacity)
            end
        end
    end
end

function draw_sublayer_object(object, video, frame, origin_matrix, layer_frames)
    # translate the object to it's starting position.
    # It's better to draw the object always at the origin and use `star_pos` to shift it
    translate(get_position(object.start_pos))

    # reset change keywords
    empty!(object.change_keywords)

    # first compute and perform the global transformations of this object
    # relative frame number for actions
    if layer_frames == nothing
        rel_frame = frame - first(get_frames(object)) + 1
    else
        # actions of objects in a layer
        # this is somewhat nested since object and action defined in a layer
        # both have their respective frame ranges that need to be calculated relatively
        rel_frame = frame - first(get_frames(object)) - first(layer_frames.frames) - first(get_frames(CURRENT_LAYER[1])) + 3
    end

    # call currently active actions and their transformations
    for action in object.actions
        if rel_frame in get_frames(action)
            action.func(video, object, action, rel_frame)
        elseif rel_frame > last(get_frames(action)) && action.keep
            # call the action on the last frame i.e. disappeared things stay disappeared
            action.func(video, object, action, last(get_frames(action)))
        end
    end

    # set the defaults for the frame like setline() and setopacity()
    # which can depend on the actions
    set_object_defaults!(object)

    # if the scale would be 0.0 `show_object` is set to false => don't show the object
    # (it wasn't actually scaled to 0 because it would break Cairo :D)
    cs = get_current_setting()
    !cs.show_object && return

    res = object.func(video, object, frame; collect(object.change_keywords)...)
    current_global_matrix = cairotojuliamatrix(getmatrix())
    # obtain current matrix without the initial matrix part
    current_matrix = inv(origin_matrix) * current_global_matrix

    # if a transformation let's save the global coordinates
    if res isa Point
        trans = current_matrix * Transformation(res, 0.0, 1.0)
        object.result[1] = trans
    elseif res isa Transformation
        trans = current_matrix * res
        object.result[1] = trans
    else # just save the result such that it can be used as one wishes
        object.result[1] = res
    end
end
