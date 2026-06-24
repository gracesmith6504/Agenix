/*
Copyright 2026.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controller

import (
	"context"
	"fmt"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	meta "k8s.io/apimachinery/pkg/api/meta"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	logf "sigs.k8s.io/controller-runtime/pkg/log"

	agentv1alpha1 "github.com/Bobbins228/Agenix/agenix-operator/api/v1alpha1"
	"github.com/Bobbins228/Agenix/agenix-operator/internal/ca"
)

// AgentIdentityReconciler reconciles a AgentIdentity object
type AgentIdentityReconciler struct {
	client.Client
	Scheme *runtime.Scheme
	CA     *ca.CA
}

// +kubebuilder:rbac:groups=agent.agenix.io,resources=agentidentities,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=agent.agenix.io,resources=agentidentities/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=agent.agenix.io,resources=agentidentities/finalizers,verbs=update
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;update;patch
// +kubebuilder:rbac:groups="",resources=secrets,verbs=get;list;watch;create;update;patch;delete

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// TODO(user): Modify the Reconcile function to compare the state specified by
// the AgentIdentity object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.24.1/pkg/reconcile
func (r *AgentIdentityReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := logf.FromContext(ctx)

	// Fetch the AgentIdentity CR
	identity := &agentv1alpha1.AgentIdentity{}
	if err := r.Get(ctx, req.NamespacedName, identity); err != nil {
		if apierrors.IsNotFound(err) {
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	// Check if the target Deployment exists
	deployment := &appsv1.Deployment{}
	deploymentName := types.NamespacedName{
		Name:      identity.Spec.TargetRef.Name,
		Namespace: req.Namespace,
	}
	if err := r.Get(ctx, deploymentName, deployment); err != nil {
		if apierrors.IsNotFound(err) {
			identity.Status.Phase = "Error"
			meta.SetStatusCondition(&identity.Status.Conditions, metav1.Condition{
				Type:               "TargetFound",
				Status:             metav1.ConditionFalse,
				Reason:             "DeploymentNotFound",
				Message:            fmt.Sprintf("Deployment %q not found in namespace %q", identity.Spec.TargetRef.Name, req.Namespace),
				LastTransitionTime: metav1.Now(),
			})
			if err := r.Status().Update(ctx, identity); err != nil {
				return ctrl.Result{}, err
			}
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	identity.Status.Phase = "Pending"
	meta.SetStatusCondition(&identity.Status.Conditions, metav1.Condition{
		Type:               "TargetFound",
		Status:             metav1.ConditionTrue,
		Reason:             "DeploymentFound",
		Message:            fmt.Sprintf("Deployment %q found", identity.Spec.TargetRef.Name),
		LastTransitionTime: metav1.Now(),
	})
	if err := r.Status().Update(ctx, identity); err != nil {
		return ctrl.Result{}, err
	}

	log.Info("Target Deployment found", "deployment", identity.Spec.TargetRef.Name, "serviceAccount",
		deployment.Spec.Template.Spec.ServiceAccountName)

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *AgentIdentityReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&agentv1alpha1.AgentIdentity{}).
		Owns(&corev1.Secret{}).
		Named("agentidentity").
		Complete(r)
}
