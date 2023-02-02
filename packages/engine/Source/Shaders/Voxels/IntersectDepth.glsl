// See IntersectionUtils.glsl for the definitions of Ray, Intersections,
// setIntersectionPair, INF_HIT, NO_HIT

/* intersectDepth defines (set in Scene/VoxelRenderResources.js)
#define DEPTH_INTERSECTION_INDEX ###
*/

uniform mat4 u_transformPositionViewToUv;

void intersectDepth(in vec2 screenCoord, in Ray ray, inout Intersections ix) {
    float logDepthOrDepth = czm_unpackDepth(texture(czm_globeDepthTexture, screenCoord));
    if (logDepthOrDepth != 0.0) {
        // Calculate how far the ray must travel before it hits the depth buffer.
        vec4 eyeCoordinateDepth = czm_screenToEyeCoordinates(screenCoord, logDepthOrDepth);
        eyeCoordinateDepth /= eyeCoordinateDepth.w;
        vec3 depthPositionUv = vec3(u_transformPositionViewToUv * eyeCoordinateDepth);
        float t = dot(depthPositionUv - ray.pos, ray.dir);
        // We don't have a normal for the depth, so use the ray direction for now
        vec4 hitPoint = vec4(-ray.dir, t);
        vec4 farSide = vec4(+ray.dir, +INF_HIT);
        setIntersectionPair(ix, DEPTH_INTERSECTION_INDEX, hitPoint, farSide);
    } else {
        // There's no depth at this location.
        setIntersectionPair(ix, DEPTH_INTERSECTION_INDEX, vec4(NO_HIT), vec4(NO_HIT));
    }
}
