struct Shape
    points::Vector{Point}
    simplified_points::Vector{Point}
    subpaths::Vector{Vector{Point}}
    num_acute_angles::Int
    num_obtuse_angles::Int
    num_right_angles::Int
end

function EmptyShape()
    return Shape(Point[], Point[], Vector{Vector{Point}}(), 0, 0, 0)
end

function Base.isempty(shape::Shape)
    return length(shape.points) == 0
end

function get_angles(p)
    # TODO: let's assume it's a closed path 
    num_acute_angles = 0
    num_obtuse_angles = 0
    num_right_angles = 0
    simplified = Point[]

    for i in 1:length(p)
        pA = p[i]
        if i < length(p) - 1
            u = p[i] - p[i + 1]
            v = p[i + 2] - p[i + 1]
            pB = p[i + 1]
            pC = p[i + 2]
        elseif i == length(p) - 1
            u = p[i] - p[i + 1]
            v = p[1] - p[i + 1]
            pB = p[i + 1]
            pC = p[1]
        else
            u = p[i] - p[1]
            v = p[2] - p[1]
            pB = p[1]
            pC = p[2]
        end
        ang = rad2deg(acos(dotproduct(u, v) / (sqrt(u.x^2 + u.y^2) * sqrt(v.x^2 + v.y^2))))
        if ang < 179.8
            push!(simplified, pB)
        end

        if ang < 160
            if ang > 100 # obtuse
                num_obtuse_angles += 1
            elseif ang < 80 # acute
                num_acute_angles += 1
            else # right
                num_right_angles += 1
            end
        end
    end
    return simplified, num_acute_angles, num_obtuse_angles, num_right_angles
end

function get_similarity(shapeA::Shape, shapeB::Shape)
    score_points = 10.0
    score_holes = 100.0
    score_acute_angles = 100.0
    score_right_angles = 100.0
    score_obtuse_angles = 100.0

    score = 0.0

    # number of points
    nA = length(shapeA.simplified_points)
    nB = length(shapeB.simplified_points)
    perc = nA < nB ? nA / nB : nB / nA
    perc = isnan(perc) ? 1.0 : perc
    # println("Point score: ", perc*score_points)
    score += perc * score_points

    # number of holes
    nA = length(shapeA.subpaths)
    nB = length(shapeB.subpaths)
    perc = nA < nB ? nA / nB : nB / nA
    perc = isnan(perc) ? 1.0 : perc
    # println("Hole score: ", perc*score_points)
    score += perc * score_holes

    # number of angles
    # acute
    nA = shapeA.num_acute_angles
    nB = shapeB.num_acute_angles
    perc = nA < nB ? nA / nB : nB / nA
    perc = isnan(perc) ? 1.0 : perc
    score += perc * score_acute_angles
    # println("Acute score: ", perc*score_points)

    # obtuse
    nA = shapeA.num_obtuse_angles
    nB = shapeB.num_obtuse_angles
    perc = nA < nB ? nA / nB : nB / nA
    perc = isnan(perc) ? 1.0 : perc
    score += perc * score_obtuse_angles
    # println("Obtuse score: ", perc*score_points)

    # right
    nA = shapeA.num_right_angles
    nB = shapeB.num_right_angles
    perc = nA < nB ? nA / nB : nB / nA
    perc = isnan(perc) ? 1.0 : perc
    score += perc * score_right_angles
    # println("right score: ", perc*score_points)

    return score
end

function create_shapes(polys)
    shapes = Vector{Shape}()

    is_last_subpath = false
    current_points = Point[]
    current_simplified_points = Point[]
    current_subpaths = Vector{Vector{Point}}()
    for poly in polys
        if ispolyclockwise(poly) && !is_last_subpath
            empty!(current_subpaths)
            if !isempty(current_points)
                current_points, aa, oa, ra = get_angles(current_simplified_points)
                shape = Shape(
                    current_points,
                    current_simplified_points,
                    Vector{Vector{Point}}(),
                    aa,
                    oa,
                    ra,
                )
                push!(shapes, shape)
            end
            current_points = poly
            current_simplified_points = simplify(poly)
            is_last_subpath = false
        elseif ispolyclockwise(poly)
            current_points, aa, oa, ra = get_angles(current_simplified_points)
            shape = Shape(
                current_points,
                current_simplified_points,
                copy(current_subpaths),
                aa,
                oa,
                ra,
            )
            push!(shapes, shape)
            is_last_subpath = false
            current_points = poly
            current_simplified_points = simplify(poly)
            empty!(current_subpaths)
        else # is a hole
            push!(current_subpaths, poly)
            is_last_subpath = true
        end
    end
    current_points, aa, oa, ra = get_angles(current_simplified_points)
    shape = Shape(current_points, current_simplified_points, current_subpaths, aa, oa, ra)
    push!(shapes, shape)
    return shapes
end