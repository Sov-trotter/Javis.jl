"""
    Layer

Defines a new layer within the video.

# Fields
- `frames::Frames`: A range of frames for which the `Layer` exists
- `width::Int`: Width of the layer
- `height::Int`: hegiht of the layer
- `position::Point`: initial positon of the center of the layer on the main canvas
- `layer_objects::Vector{AbstractObject}`: Objects defined under the layer
- `actions::Vector{AbstractAction}`: a list of actions applied to the entire layer 
- `current_setting::LayerSetting`: The current state of the layer see [`LayerSetting`](@ref)
- `opts::Dict{Symbol,Any}`: can hold any options defined by the user
- `image_matrix::Vector`: Hold the Drwaing of the layer as a Luxor image matrix
"""
mutable struct Layer <: AbstractObject
    frames::Frames
    width::Int
    height::Int
    position::Point
    layer_objects::Vector{AbstractObject}
    actions::Vector{AbstractAction}
    current_setting::LayerSetting
    opts::Dict{Symbol,Any}
    image_matrix::Union{Base.ReinterpretArray{ARGB32,2,UInt32,Matrix{UInt32},false},Nothing}
    layer_cache::LayerCache
end

"""
    CURRENT_LAYER

holds the current layer in an array to be declared as a constant
The current layer can be accessed using CURRENT_LAYER[1]
"""
const CURRENT_LAYER = Array{Layer,1}()

# for width, height and position defaults are defined in the to_layer_m function
function Layer(
    frames,
    width::Int,
    height::Int,
    position::Point;
    layer_objects = AbstractObject[],
    actions = AbstractAction[],
    setting = LayerSetting(),
    misc = Dict{Symbol,Any}(),
    mat = nothing,
    layer_cache = LayerCache(),
)
    layer = Layer(
        frames,
        width,
        height,
        position,
        layer_objects,
        actions,
        setting,
        misc,
        mat,
        layer_cache,
    )

    if isempty(CURRENT_LAYER)
        push!(CURRENT_LAYER, layer)
    else
        CURRENT_LAYER[1] = layer
    end
    push!(CURRENT_VIDEO[1].layers, layer)

    return layer
end
