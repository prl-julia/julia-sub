# Getting Started

## Installation

First, obtain Julia 1.3 or later, available [here](https://julialang.org/downloads/).

The Gen package can be installed with the Julia package manager. From the Julia REPL, type `]` to enter the Pkg REPL mode and then run:
```
pkg> add Gen
```
To test the installation locally, you can run the tests with:
```julia
using Pkg; Pkg.test("Gen")
```

## Example

Let's write a short Gen program that does Bayesian linear regression: given a set of points in the (x, y) plane, we want to find a line that fits them well.

There are three main components to a typical Gen program.

First, we define a _generative model_: a Julia function, extended with some extra syntax, that, conceptually, simulates a fake dataset. The model below samples `slope` and `intercept` parameters, and then for each of the x-coordinates that it accepts as input, samples a corresponding y-coordinate. We name the random choices we make with `@trace`, so we can refer to them in our inference program.

```julia
using Gen

@gen function my_model(xs::Vector{Float64})
    slope = @trace(normal(0, 2), :slope)
    intercept = @trace(normal(0, 10), :intercept)
    for (i, x) in enumerate(xs)
        @trace(normal(slope * x + intercept, 1), "y-$i")
    end
end
```

Second, we write an _inference program_ that implements an algorithm for manipulating the execution traces of the model.
Inference programs are regular Julia code, and make use of Gen's standard inference library.

The inference program below takes in a data set, and runs an iterative MCMC algorithm to fit `slope` and `intercept` parameters:

```julia
function my_inference_program(xs::Vector{Float64}, ys::Vector{Float64}, num_iters::Int)
    # Create a set of constraints fixing the 
    # y coordinates to the observed y values
    constraints = choicemap()
    for (i, y) in enumerate(ys)
        constraints["y-$i"] = y
    end
    
    # Run the model, constrained by `constraints`,
    # to get an initial execution trace
    (trace, _) = generate(my_model, (xs,), constraints)
    
    # Iteratively update the slope then the intercept,
    # using Gen's metropolis_hastings operator.
    for iter=1:num_iters
        (trace, _) = metropolis_hastings(trace, select(:slope))
        (trace, _) = metropolis_hastings(trace, select(:intercept))
    end
    
    # From the final trace, read out the slope and
    # the intercept.
    choices = get_choices(trace)
    return (choices[:slope], choices[:intercept])
end
```

Finally, we run the inference program on some data, and get the results:

```julia
xs = [1., 2., 3., 4., 5., 6., 7., 8., 9., 10.]
ys = [8.23, 5.87, 3.99, 2.59, 0.23, -0.66, -3.53, -6.91, -7.24, -9.90]
(slope, intercept) = my_inference_program(xs, ys, 1000)
println("slope: $slope, intercept: $intercept")
```
