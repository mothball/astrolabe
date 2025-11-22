import heyoka
from sgp4.api import Satrec, WGS72

print("Inspecting Heyoka API...")
try:
    s = Satrec()
    s.sgp4init(WGS72, 'i', 0, 0.0, 0.00001, 0.0, 0.0, 0.0001, 0.0, 0.0, 0.0, 0.0, 0.0)
    prop = heyoka.model.sgp4_propagator([s])
    print("Propagator methods:")
    print(dir(prop))
    print("\nTesting call with t=0.0:")
    try:
        res = prop(0.0)
        print(f"Result type: {type(res)}")
        print(f"Result shape/len: {len(res) if hasattr(res, '__len__') else 'scalar'}")
        print(f"Result sample: {res[0] if hasattr(res, '__getitem__') else res}")
    except Exception as e:
        print(f"Call failed: {e}")

    print("\nTesting call with t=[0.0, 10.0]:")
    try:
        res = prop([0.0, 10.0])
        print(f"Result type: {type(res)}")
    except Exception as e:
        print(f"List call failed: {e}")
except Exception as e:
    print(f"Error: {e}")
