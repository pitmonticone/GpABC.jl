using Test, GpABC, DelimitedFiles
import GpABC.covariance, GpABC.get_hyperparameters_size

struct NoGradKernel <: AbstractGPKernel
    rbf_iso_kernel::GpABC.SquaredExponentialIsoKernel
end

function NoGradKernel()
    NoGradKernel(GpABC.SquaredExponentialIsoKernel())
end

function get_hyperparameters_size(ker::NoGradKernel, x::AbstractArray{Float64, 2})
    get_hyperparameters_size(ker.rbf_iso_kernel, x)
end

function covariance(ker::NoGradKernel, log_theta::AbstractArray{Float64, 1},
    x1::AbstractArray{Float64, 2}, x2::AbstractArray{Float64, 2})
    covariance(ker.rbf_iso_kernel, log_theta, x1, x2)
end


@testset "GP Reression Tests" begin
    training_x = readdlm("$(@__DIR__)/training_x1.csv")
    training_y = readdlm("$(@__DIR__)/training_y1.csv")
    test_x = readdlm("$(@__DIR__)/test_x1.csv")

    gpem = GPModel(training_x, training_y, test_x)

    theta_mle = gp_train(gpem)
    @test [58.7668, 2.94946, 5.84869] ≈ theta_mle rtol=1e-5
    @test -183.80873007668373 ≈ gp_loglikelihood(gpem)
    test_grad = gp_loglikelihood_grad(log.(gpem.gp_hyperparameters), gpem)
    @test all(abs.(test_grad - [46540815059614715e-22, 6451822871511581e-22, 20565826801544063e-22]) .< 1e-5)

    regression_mean = readdlm("$(@__DIR__)/test_y1_mean.csv")
    regression_var = readdlm("$(@__DIR__)/test_y1_var.csv")
    (r_mean, r_var) = gp_regression(gpem, batch_size=10)
    @test r_mean ≈ regression_mean
    @test r_var ≈ regression_var rtol=1e-3

    regression_cov = readdlm("$(@__DIR__)/test_y1_cov.csv", ',')
    (r_mean, r_cov) = gp_regression(gpem, batch_size=10, full_covariance_matrix=true)
    @test r_cov ≈ regression_cov rtol=1e-3

    gpem = GPModel(training_x, training_y, NoGradKernel())
    theta_mle = gp_train(gpem)
    @test [58.7668, 2.94946, 5.84869] ≈ theta_mle rtol=1e-3

    # Test that 1-d inputs work
    training_x = reshape(training_x, size(training_x, 1))
    training_y = reshape(training_y, size(training_y, 1))
    gpem = GPModel(training_x, training_y)
    theta_mle = gp_train(gpem)

end

@testset "GP Regression Sampler Tests" begin

    training_x = readdlm("$(@__DIR__)/training_x1.csv")
    training_y = readdlm("$(@__DIR__)/training_y1.csv")
    test_x = readdlm("$(@__DIR__)/test_x1.csv")
    n_samples = 1000000

    gpem = GPModel(training_x, training_y, test_x)

    gp_mean, gp_var = gp_regression(gpem)
    posterior_samples = gp_regression_sample(test_x, n_samples, gpem)

    @test size(posterior_samples,1)==size(test_x,1)
    @test size(posterior_samples,2)==n_samples  

    @test isapprox(gp_mean, mean(posterior_samples, dims=2), rtol=1e-2)
    @test isapprox(gp_var, var(posterior_samples, dims=2), rtol=1e-2)

    posterior_sample = gp_regression_sample(test_x, 1, gpem)
    @test size(posterior_sample)==(size(test_x,1),)

end
