// See IntersectionUtils.glsl for the definitions of Ray, Intersections, INF_HIT,
// NO_HIT, setIntersectionPair

/* Clipping plane defines (set in Scene/VoxelRenderResources.js)
#define CLIPPING_PLANES_UNION
#define CLIPPING_PLANES_COUNT
#define CLIPPING_PLANES_INTERSECTION_INDEX
*/

uniform sampler2D u_clippingPlanesTexture;
uniform mat4 u_clippingPlanesMatrix;

// Plane is in Hessian Normal Form
vec4 intersectPlane(in Ray ray, in vec4 plane) {
    vec3 o = ray.pos;
    vec3 d = ray.dir;
    vec3 n = plane.xyz; // normal
    float w = plane.w; // -dot(pointOnPlane, normal)

    float a = dot(o, n);
    float b = dot(d, n);
    float t = -(w + a) / b;

    return vec4(n, t);
}

void intersectClippingPlanes(in Ray ray, inout Intersections ix) {
    vec4 farSide = vec4(ray.dir, +INF_HIT);
    vec4 backSide = vec4(-ray.dir, -INF_HIT);
    #if (CLIPPING_PLANES_COUNT == 1)
        // Union and intersection are the same when there's one clipping plane, and the code
        // is more simplified.
        vec4 planeUv = getClippingPlane(u_clippingPlanesTexture, 0, u_clippingPlanesMatrix);
        // The clipping volume is defined by the plane and the half-space boundary.
        // We add these to the list in arbitrary order, since the list will be sorted anyway
        vec4 planeIntersection = intersectPlane(ray, planeUv);
        vec4 spaceIntersection = dot(ray.dir, planeUv.xyz) > 0.0 ? farSide : backSide;
        setIntersectionPair(ix, CLIPPING_PLANES_INTERSECTION_INDEX, planeIntersection, spaceIntersection);
    #elif defined(CLIPPING_PLANES_UNION)
        vec4 firstEntry = farSide;
        vec4 lastExit = backSide;
        for (int i = 0; i < CLIPPING_PLANES_COUNT; i++) {
            vec4 planeUv = getClippingPlane(u_clippingPlanesTexture, i, u_clippingPlanesMatrix);
            vec4 intersection = intersectPlane(ray, planeUv);
            if (dot(ray.dir, planeUv.xyz) > 0.0) {
                firstEntry = intersection.w < firstEntry.w ? intersection : firstEntry;
            } else {
                lastExit = intersection.w > lastExit.w ? intersection : lastExit;
            }
        }
        setIntersectionPair(ix, CLIPPING_PLANES_INTERSECTION_INDEX + 0, backSide, lastExit);
        setIntersectionPair(ix, CLIPPING_PLANES_INTERSECTION_INDEX + 1, firstEntry, farSide);
    #else // intersection
        vec4 lastEntry = backSide;
        vec4 firstExit = farSide;
        for (int i = 0; i < CLIPPING_PLANES_COUNT; i++) {
            vec4 planeUv = getClippingPlane(u_clippingPlanesTexture, i, u_clippingPlanesMatrix);
            vec4 intersection = intersectPlane(ray, planeUv);
            if (dot(ray.dir, planeUv.xyz) > 0.0) {
                lastEntry = intersection.w > lastEntry.w ? intersection : lastEntry;
            } else {
                firstExit = intersection.w < firstExit.w ? intersection : firstExit;
            }
        }
        if (lastEntry.w < firstExit.w) {
            setIntersectionPair(ix, CLIPPING_PLANES_INTERSECTION_INDEX, firstExit, lastEntry);
        } else {
            setIntersectionPair(ix, CLIPPING_PLANES_INTERSECTION_INDEX, vec4(NO_HIT), vec4(NO_HIT));
        }
    #endif
}
