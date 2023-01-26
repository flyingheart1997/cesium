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

struct RaySurfaceIntersection {
    // Distance along ray from ray origin to intersection
    float t;
    // type = 0: positive shape entry
    // type = 1: positive shape exit
    // type = 2: negative shape entry
    // type = 3: negative shape exit
    // TODO: use integer
    float type;
    // vec3 normal;
};

struct Intersections {
    // Don't access these member variables directly - call the functions instead.

    #if (INTERSECTION_COUNT > 1)
        // Store an array of intersections. Each intersection is composed of:
        //  x for the T value
        //  y for the shape type - which encodes positive vs negative and entering vs exiting
        // For example:
        //  y = 0: positive shape entry
        //  y = 1: positive shape exit
        //  y = 2: negative shape entry
        //  y = 3: negative shape exit
        //vec2 intersections[INTERSECTION_COUNT * 2];
        RaySurfaceIntersection intersections[INTERSECTION_COUNT * 2];

        // Maintain state for future nextIntersection calls
        int index;
        int surroundCount;
        bool surroundIsPositive;
    #else
        // When there's only one positive shape intersection none of the extra stuff is needed.
        float intersections[2];
    #endif
};

// Using a define instead of a real function because WebGL1 cannot access array with non-constant index.
#if (INTERSECTION_COUNT > 1)
    #define getIntersection(/*inout Intersections*/ ix, /*int*/ index) (ix).intersections[(index)].t
#else
    #define getIntersection(/*inout Intersections*/ ix, /*int*/ index) (ix).intersections[(index)]
#endif

// Using a define instead of a real function because WebGL1 cannot access array with non-constant index.
#define getIntersectionPair(/*inout Intersections*/ ix, /*int*/ index) vec2(getIntersection((ix), (index) * 2 + 0), getIntersection((ix), (index) * 2 + 1))

// Using a define instead of a real function because WebGL1 cannot access array with non-constant index.
#if (INTERSECTION_COUNT > 1)
    #define setIntersection(/*inout Intersections*/ ix, /*int*/ index, /*float*/ t, /*bool*/ positive, /*bool*/ enter) (ix).intersections[(index)] = RaySurfaceIntersection((t), float(!positive) * 2.0 + float(!enter))
#else
    #define setIntersection(/*inout Intersections*/ ix, /*int*/ index, /*float*/ t, /*bool*/ positive, /*bool*/ enter) (ix).intersections[(index)] = (t)
#endif

// Using a define instead of a real function because WebGL1 cannot access array with non-constant index.
#if (INTERSECTION_COUNT > 1)
    #define setIntersectionPair(/*inout Intersections*/ ix, /*int*/ index, /*vec2*/ entryExit) (ix).intersections[(index) * 2 + 0] = RaySurfaceIntersection((entryExit).x, float((index) > 0) * 2.0 + 0.0); (ix).intersections[(index) * 2 + 1] = RaySurfaceIntersection((entryExit).y, float((index) > 0) * 2.0 + 1.0)
#else
    #define setIntersectionPair(/*inout Intersections*/ ix, /*int*/ index, /*vec2*/ entryExit) (ix).intersections[(index) * 2 + 0] = (entryExit).x; (ix).intersections[(index) * 2 + 1] = (entryExit).y
#endif

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

            RaySurfaceIntersection intersect0 = ix.intersections[i + 0];
            RaySurfaceIntersection intersect1 = ix.intersections[i + 1];

            float t0 = intersect0.t;
            float t1 = intersect1.t;
            float type0 = intersect0.type;
            float type1 = intersect1.type;

            float tmin = min(t0, t1);
            float tmax = max(t0, t1);
            float bmin = tmin == t0 ? type0 : type1;
            float bmax = tmin == t0 ? type1 : type0;

            ix.intersections[i + 0] = RaySurfaceIntersection(tmin, bmin);
            ix.intersections[i + 1] = RaySurfaceIntersection(tmax, bmax);
        }
    }

    // Prepare initial state for nextIntersection
    ix.index = 0;
    ix.surroundCount = 0;
    ix.surroundIsPositive = false;
}
#endif

#if (INTERSECTION_COUNT > 1)
vec2 nextIntersection(inout Intersections ix) {
    vec2 entryExitT = vec2(NO_HIT);

    const int passCount = INTERSECTION_COUNT * 2;

    if (ix.index == passCount) {
        return entryExitT;
    }

    for (int i = 0; i < passCount; ++i) {
        // The loop should be: for (i = ix.index; i < passCount; ++i) {...} but WebGL1 cannot
        // loop with non-constant condition, so it has to continue instead.
        if (i < ix.index) {
            continue;
        }

        ix.index = i + 1;

        RaySurfaceIntersection intersect = ix.intersections[i];
        float t = intersect.t;
        bool currShapeIsPositive = intersect.type < 2.0;
        bool enter = mod(intersect.type, 2.0) == 0.0;

        ix.surroundCount += enter ? +1 : -1;
        ix.surroundIsPositive = currShapeIsPositive ? enter : ix.surroundIsPositive;

        // entering positive or exiting negative
        if (ix.surroundCount == 1 && ix.surroundIsPositive && enter == currShapeIsPositive) {
            entryExitT.x = t;
        }

        // exiting positive or entering negative after being inside positive
        // TODO: Can this be simplified?
        bool exitPositive = !enter && currShapeIsPositive && ix.surroundCount == 0;
        bool enterNegativeFromPositive = enter && !currShapeIsPositive && ix.surroundCount == 2 && ix.surroundIsPositive;
        if (exitPositive || enterNegativeFromPositive) {
            entryExitT.y = t;

            // entry and exit have been found, so the loop can stop
            if (exitPositive) {
                // After exiting positive shape there is nothing left to intersect, so jump to the end index.
                ix.index = passCount;
            }
            break;
        }
    }

    return entryExitT;
}
#endif

// NOTE: initializeIntersections, nextIntersection aren't even declared unless INTERSECTION_COUNT > 1
// export { NO_HIT, INF_HIT, Ray, Intersections, getIntersectionPair, setIntersectionPair, initializeIntersections, nextIntersection };
