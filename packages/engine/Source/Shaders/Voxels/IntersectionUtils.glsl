/* Intersection defines
#define INTERSECTION_COUNT ###
*/

#define NO_HIT (-czm_infinity)
#define INF_HIT (czm_infinity * 0.5)

struct Ray {
    vec3 pos;
    vec3 dir;
#if defined(SHAPE_BOX)
    vec3 dInv;
#endif
};

struct Intersections {
    // Don't access these member variables directly - call the functions instead.

    // Store an array of intersections. Each intersection is composed of:
    //  .xyz for the surface normal at the intersection point
    //  .w for the T value
    // The normal is scaled by 2 for positive shapes
    // INTERSECTION_COUNT is the number of ray-*shape* (volume) intersections,
    // so we need twice as many to track ray-*surface* intersections
    vec4 intersections[INTERSECTION_COUNT * 2];

    #if (INTERSECTION_COUNT > 1)
        // Maintain state for future nextIntersection calls
        int index;
        int surroundCount;
        bool surroundIsPositive;
    #endif
};

// Using a define instead of a real function because WebGL1 cannot access array with non-constant index.
#if (INTERSECTION_COUNT > 1)
    #define setIntersection(/*inout Intersections*/ ix, /*int*/ index, /*float*/ t, /*bool*/ positive, /*bool*/ enter) (ix).intersections[(index)] = vec2((t), float(!positive) * 2.0 + float(!enter))
#else
    #define setIntersection(/*inout Intersections*/ ix, /*int*/ index, /*float*/ t, /*bool*/ positive, /*bool*/ enter) (ix).intersections[(index)] = (t)
#endif

// Using a define instead of a real function because WebGL1 cannot access array with non-constant index.
#define setIntersectionPair(/*inout Intersections*/ ix, /*int*/ index, /*vec4*/ entry, /*vec4*/ exit) (ix).intersections[(index) * 2 + 0] = entry; (ix).intersections[(index) * 2 + 1] = exit

#if (INTERSECTION_COUNT > 1)
void initializeIntersections(inout Intersections ix) {
    // Sort the intersections from min T to max T with bubble sort.
    // Note: If this sorting function changes, some of the intersection test may
    // need to be updated. Search for "bubble sort" to find those areas.
    const int sortPasses = INTERSECTION_COUNT * 2 - 1;
    for (int n = sortPasses; n > 0; --n) {
        for (int i = 0; i < sortPasses; ++i) {
            // The loop should be: for (i = 0; i < n; ++i) {...} but WebGL1 cannot
            // loop with non-constant condition, so it has to break early instead
            if (i >= n) { break; }

            vec4 intersect0 = ix.intersections[i + 0];
            vec4 intersect1 = ix.intersections[i + 1];

            bool inOrder = intersect0.w <= intersect1.w;

            ix.intersections[i + 0] = inOrder ? intersect0 : intersect1;
            ix.intersections[i + 1] = inOrder ? intersect1 : intersect0;
        }
    }

    // Prepare initial state for nextIntersection
    ix.index = 0;
    ix.surroundCount = 0;
    ix.surroundIsPositive = false;
}
#endif

#if (INTERSECTION_COUNT > 1)
void nextIntersection(inout Intersections ix, in vec3 dir, out vec4 entry, out vec4 exit) {
    entry = vec4(NO_HIT);
    exit = vec4(NO_HIT);

    const int passCount = INTERSECTION_COUNT * 2;

    if (ix.index == passCount) {
        return;
    }

    for (int i = 0; i < passCount; ++i) {
        // The loop should be: for (i = ix.index; i < passCount; ++i) {...} but WebGL1 cannot
        // loop with non-constant condition, so it has to continue instead.
        if (i < ix.index) {
            continue;
        }

        ix.index = i + 1;

        vec4 intersect = ix.intersections[i];
        vec3 normal = intersect.xyz;
        float t = intersect.w;
        // Is this the main shape of the voxel primitive? Otherwise it is a
        // negative volume (e.g., a a clipping plane or render bound)
        bool currShapeIsPositive = dot(normal, normal) >= 2.0;
        bool enter = dot(dir, normal) <= 0.0;

        // How many nested shapes are we inside?
        ix.surroundCount += enter ? +1 : -1;
        ix.surroundIsPositive = currShapeIsPositive ? enter : ix.surroundIsPositive;

        // entering positive or exiting negative
        if (ix.surroundCount == 1 && ix.surroundIsPositive && enter == currShapeIsPositive) {
            entry = vec4(normalize(dir), t);
        }

        // exiting positive or entering negative after being inside positive
        // TODO: Can this be simplified?
        bool exitPositive = !enter && currShapeIsPositive && ix.surroundCount == 0;
        bool enterNegativeFromPositive = enter && !currShapeIsPositive && ix.surroundCount == 2 && ix.surroundIsPositive;
        if (exitPositive || enterNegativeFromPositive) {
            exit = vec4(normalize(dir), t);

            // entry and exit have been found, so the loop can stop
            if (exitPositive) {
                // After exiting positive shape there is nothing left to intersect, so jump to the end index.
                ix.index = passCount;
            }
            break;
        }
    }
}
#endif

// NOTE: initializeIntersections, nextIntersection aren't even declared unless INTERSECTION_COUNT > 1
