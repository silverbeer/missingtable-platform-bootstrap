resource "aws_iam_role" "eks_cluster_role" {
    name = "${var.cluster_name}-eks-cluster-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "eks.amazonaws.com"
                }
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_role_policy_attachment" {
    role = aws_iam_role.eks_cluster_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_node_group_role" {
    name = "${var.cluster_name}-eks-node-group-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "ec2.amazonaws.com"
                }
            } 
        ]
    })
}

resource "aws_iam_role_policy_attachment" "eks_node_group_role_policy_attachment" {
    role = aws_iam_role.eks_node_group_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy_attachment" {
    role = aws_iam_role.eks_node_group_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read_only_attachment" {
    role = aws_iam_role.eks_node_group_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_cluster" "main" {
    name = var.cluster_name
    version = var.cluster_version
    role_arn = aws_iam_role.eks_cluster_role.arn
    vpc_config {
        subnet_ids = concat(var.public_subnet_ids, var.private_subnet_ids)
    }

    depends_on = [aws_iam_role_policy_attachment.eks_cluster_role_policy_attachment]

    tags = {
        Name = var.cluster_name
    }
}

resource "aws_eks_node_group" "main" {
    cluster_name = aws_eks_cluster.main.name    
    node_group_name = "${var.cluster_name}-eks-node-group"
    node_role_arn = aws_iam_role.eks_node_group_role.arn
    subnet_ids = var.private_subnet_ids

    scaling_config {
        desired_size = 2
        max_size = 3
        min_size = 1
    }
    instance_types = ["t3.micro"]

    depends_on = [
        aws_iam_role_policy_attachment.eks_node_group_role_policy_attachment, 
        aws_iam_role_policy_attachment.cni_policy_attachment, 
        aws_iam_role_policy_attachment.ec2_container_registry_read_only_attachment
    ]

    tags = {
        Name = "${var.cluster_name}-eks-node-group"
    }    
    
    
    
}