<template>
    <div @click="select">
        <template v-if="$store.state.editCell === cell">
            <input maxlength="20" v-model="cell.name" placeholder="Name..."/>
        </template>
        <template v-else>
            {{ cell.name }}
        </template>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import {Value} from "../engine/engine";

export default Vue.component('ColumnHead', {
    name: 'ColumnHead',
    props: {
        'cell': {type: Value},
    },
    computed: {
    },
    methods: {
        select: function(event: Event) {
            this.$store.commit("setEdit", this.cell);
            event.stopPropagation();
        }

    }

});
</script>

<style>
</style>
