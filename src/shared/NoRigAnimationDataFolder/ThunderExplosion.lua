return {
    AnimationType = "NoRig",
    Behaviors = {
        [1] = {
            Enabled = {
                [0] = {
                    Values = false,
                },
                [40] = {
                    Values = true,
                },
                [99] = {
                    Values = false,
                },
            },
        },
        [2] = {
            Emit = {
                [1] = {
                    Values = 60,
                },
            },
        },
        [3] = {
            Emit = {
                [1] = {
                    Values = 15,
                },
            },
        },
        [4] = {
            Emit = {
                [1] = {
                    Values = 200,
                },
            },
        },
        [5] = {
            Emit = {
                [1] = {
                    Values = 15,
                },
            },
        },
    },
    Items = {
        [1] = {
            Attachment = false,
            Name = "Sparks",
            Place = "A - Sparks [A]",
            Type = "ParticleEmitter",
        },
        [2] = {
            Attachment = false,
            Name = "BlueSmoke",
            Place = "Drain",
            Type = "ParticleEmitter",
        },
        [3] = {
            Attachment = false,
            Name = "GreySmoke",
            Place = "Drain",
            Type = "ParticleEmitter",
        },
        [4] = {
            Attachment = false,
            Name = "Partiles",
            Place = "Drain",
            Type = "ParticleEmitter",
        },
        [5] = {
            Attachment = false,
            Name = "WhiteSmoke",
            Place = "Drain",
            Type = "ParticleEmitter",
        },
    },
    Loop = false,
    Name = "ThunderExplosion",
    Priority = "Action",
    Speed = 1,
    Weight = 1,
    isExclusive = false,
}