// Main intersection function for Voxel scenes.
// See IntersectBox.glsl, IntersectCylinder.glsl, or IntersectEllipsoid.glsl
// for the definition of intersectShape. The appropriate function is selected
// based on the VoxelPrimitive shape type, and added to the shader in
// Scene/VoxelRenderResources.js.
// See also IntersectClippingPlane.glsl and IntersectDepth.glsl.
// See IntersectionUtils.glsl for the definitions of Ray, NO_HIT,
// initializeIntersections, nextIntersection.

/* Intersection defines (set in Scene/VoxelRenderResources.js)
#define INTERSECTION_COUNT ###
*/

void intersectScene(in vec2 screenCoord, in Ray ray, out Intersections ix, out vec4 entry, out vec4 exit) {
    // Do a ray-shape intersection to find the exact starting and ending points.
    intersectShape(ray, ix);

    // Exit early if the positive shape was completely missed or behind the ray.
    entry = ix.intersections[0];
    exit = ix.intersections[1];
    if (entry.w == NO_HIT) {
        // Positive shape was completely missed - so exit early.
        return;
    }

    // Clipping planes
    #if defined(CLIPPING_PLANES)
        intersectClippingPlanes(ray, ix);
    #endif

    // Depth
    #if defined(DEPTH_TEST)
        intersectDepth(screenCoord, ray, ix);
    #endif

    // Find the first intersection that's in front of the ray
    #if (INTERSECTION_COUNT > 1)
        initializeIntersections(ix);
        for (int i = 0; i < INTERSECTION_COUNT; ++i) {
            nextIntersection(ix, ray.dir, entry, exit);
            if (exit.w > 0.0) {
                // Set start to 0.0 when ray is inside the shape.
                entry.w = max(entry.w, 0.0);
                break;
            }
        }
    #else
        // Set start to 0.0 when ray is inside the shape.
        entry.w = max(entry.w, 0.0);
    #endif
}
