@testset "map_optimize" begin

    # smoke test a function without retval gradient
    @gen function foo()
        x = @trace(normal(0, 1), :x)
        return x
    end

    (trace, _) = generate(foo, ())
    new_trace = map_optimize(trace, select(:x))

    # smoke test a function with retval gradient
    @gen (grad) function foo()
        x = @trace(normal(0, 1), :x)
        return x
    end

    (trace, _) = generate(foo, ())
    new_trace = map_optimize(trace, select(:x))
end
